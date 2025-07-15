/*<info serverAlias="DBCUST-AgencyCashService" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROC [dbo].[NAP_Domain_CashDomainUpd]
	 @DomainList	NVARCHAR(MAX)
	,@UserID		INT
	,@IP			VARCHAR(50)	= ''
	,@ErrCode		INT=0			 OUTPUT
	,@ErrMsg		VARCHAR(2000)='' OUTPUT		
AS
/*
	Created: 20250703@Johnson
	Task: update Agency Cash Service domain when assign or remove site or on/off cash service
	DB: DBCUST-AgencyCashService
	
	Revisions:	
		-  20250703@Johnson: offer Agency Cash Service [RedmineID: #231219]
	Param's Explanation:
		 @DomainList :
		 		<DomainList>
						<Domain id="111" s="1045,1046" cs="1" d="1045.simplec.com"/>
						<Domain id="111" s="1050,1051" cs="0" d="1050.simplec.com"/>
						<Domain id="112" s="1047,1048" cs="0" d="1047.simplec.com"/>
						<Domain id="113" s="1052,1053" cs="1" d="1052.simplec.com"/>
				</DomainList>
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tmpDomain TABLE (
			 DomainID		SMALLINT
			,Domain			VARCHAR(50)
			,SiteID			INT
			,CashService	BIT
			,Site 			VARCHAR(50)
	)

	--active domains remaining for site removed
	DECLARE @tmpDomainActive TABLE (
			 DomainID		SMALLINT
			,Domain			VARCHAR(50)
			,SiteID			INT	
			,Site 			VARCHAR(50)		
	)

	-- Table to store operations for logging
	DECLARE @Operations TABLE (
			 RowID			INT IDENTITY(1,1)
			,AgentID		INT
			,DomainID		SMALLINT
			,DomainName		VARCHAR(50)
			,Action			VARCHAR(10)
		)

	CREATE TABLE #tblCust(
			 CustID			INT PRIMARY KEY
			,Site			VARCHAR(50)
			,cntDomain		TINYINT DEFAULT 0
	)

	DECLARE @xml XML = CAST(@DomainList AS XML)

	;WITH T AS 
	(
		SELECT
		T.N.value('@id', 'SMALLINT') AS DomainID,
		T.N.value('@d', 'VARCHAR(50)') AS Domain,
		T.N.value('@s', 'VARCHAR(500)') AS Site,
		T.N.value('@cs', 'BIT') AS CashService
	FROM @xml.nodes('/DomainList/Domain') AS T(N)
	)
	INSERT INTO @tmpDomain (DomainID, Domain, SiteID, CashService)
	SELECT
        t.DomainID,
				t.Domain,
        TRIM(s.value) AS SiteID,
        t.CashService
    FROM T
    CROSS APPLY STRING_SPLIT(t.Site, ',') s
	
	UPDATE t
	SET t.Site = s.Site
	FROM @tmpDomain t
	INNER JOIN CustDB.dbo.Site s WITH(NOLOCK) ON s.SiteID = t.siteid

	-- Debug: Check if domain names are properly captured
	-- SELECT * FROM @tmpDomain WHERE Domain IS NULL

	INSERT INTO #tblCust (CustID, Site)
	SELECT c.custid, c.site
	FROM CustDB.dbo.customer c WITH(NOLOCK)
		CROSS APPLY (SELECT TOP 1 custid FROM  CustDB.dbo.CustProductStatus cs WITH(NOLOCK) WHERE cs.CustID = c.CustID AND cs.ServiceType = 1) t
	WHERE roleid = 2
		AND site IN (SELECT site FROM @tmpDomain)

	--remove customer have site turn off domain
	IF EXISTS (SELECT 1 FROM @tmpDomain WHERE CashService = 0)
	BEGIN
		-- Capture records to be deleted for logging
		INSERT INTO @Operations (AgentID, DomainID, DomainName, Action)
		SELECT cd.AgentID, cd.DomainID, td.Domain, 'Delete'
		FROM CashDomainManagement cd WITH(NOLOCK)
		INNER JOIN #tblCust t ON t.custid = cd.AgentID
		CROSS APPLY (SELECT * FROM @tmpDomain td WHERE td.Site = t.Site AND CashService = 0) td
		WHERE cd.DomainID = td.DomainID
			AND td.Domain IS NOT NULL

		DELETE d 
		FROM CashDomainManagement d WITH(ROWLOCK)
		WHERE EXISTS (SELECT 1 
						FROM #tblCust t
						CROSS APPLY (SELECT * FROM @tmpDomain td WHERE td.Site = t.Site AND CashService = 0) s						
					WHERE t.custid = d.AgentID
						AND s.DomainID = d.DomainID)	

		-- Only add domains that are still active (not the ones we just deleted)
		-- For now, we'll keep this empty since we're only handling the domains from input XML
		-- INSERT INTO @tmpDomainActive (DomainID, Domain, SiteID)
		-- SELECT td.DomainID, td.Domain, td.SiteID
		-- FROM @tmpDomain td
		-- WHERE td.CashService = 0

		UPDATE t
		SET t.Site = s.Site
		FROM @tmpDomainActive t
		INNER JOIN CustDB.dbo.Site s WITH(NOLOCK) ON s.SiteID = t.siteid	
	END

	;WITH tmpCash AS(
		SELECT AgentID, COUNT(1) cnt
		FROM CashDomainManagement WITH(NOLOCK)
		WHERE AgentID IN (SELECT CustID FROM #tblCust)
		GROUP BY AgentID	
	)
	UPDATE t
	SET t.cntDomain = tc.cnt
	FROM #tblCust t
		INNER JOIN tmpCash tc ON tc.AgentID = t.CustID

	IF NOT EXISTS (SELECT 1 FROM #tblCust WHERE cntDomain <= 1)
		RETURN;

	BEGIN TRY
		-- Capture records to be inserted for logging (only non-duplicates)
		INSERT INTO @Operations (AgentID, DomainID, DomainName, Action)
		SELECT t.CustID, s.DomainID, s.Domain, 'Add'
		FROM #tblCust t
			CROSS APPLY (SELECT TOP (2) * 
						FROM (SELECT Site,DomainID, Domain
							FROM @tmpDomain WHERE CashService = 1
							) d
						WHERE d.Site = t.Site
						) s
		WHERE t.cntDomain = 0
			AND NOT EXISTS (SELECT 1 FROM CashDomainManagement cdm WHERE cdm.AgentID = t.CustID AND cdm.DomainID = s.DomainID)
			AND s.Domain IS NOT NULL
		
		UNION ALL
		
		SELECT t.CustID, s.DomainID, s.Domain, 'Add'
		FROM #tblCust t
			CROSS APPLY(SELECT TOP (1) * 
						FROM (SELECT Site,DomainID, Domain
							FROM @tmpDomain WHERE CashService = 1
							) d
						WHERE d.Site = t.Site
						) s
		WHERE t.cntDomain = 1
			AND NOT EXISTS (SELECT 1 FROM CashDomainManagement cdm WHERE cdm.AgentID = t.CustID AND cdm.DomainID = s.DomainID)
			AND s.Domain IS NOT NULL

		-- Insert for customers with cntDomain = 0 (no existing domains)
		INSERT INTO CashDomainManagement (AgentID, DomainID, SubDomainPrefix,RepUpdateTime)
		SELECT t.CustID, 
			s.DomainID, 
			'simplec-' + LEFT(CAST(t.CustID AS VARCHAR), 3) + 
								CAST(s.DomainID AS VARCHAR(20)) +
								SUBSTRING(CAST(t.CustID AS VARCHAR), 4, LEN(CAST(t.CustID AS VARCHAR)) - 3) AS SubDomainPrefix,
			dbo.f_GetDateTime2()							
		FROM #tblCust t
			CROSS APPLY (SELECT TOP (2) * 
						FROM (SELECT Site,DomainID
							FROM @tmpDomain WHERE CashService = 1
							) d
						WHERE d.Site = t.Site
						) s
		WHERE t.cntDomain = 0
			AND NOT EXISTS (SELECT 1 FROM CashDomainManagement cdm WHERE cdm.AgentID = t.CustID AND cdm.DomainID = s.DomainID)
		
		-- Insert for customers with cntDomain = 1 (one existing domain)
		INSERT INTO CashDomainManagement (AgentID, DomainID, SubDomainPrefix,RepUpdateTime)
		SELECT t.CustID, 
			s.DomainID, 
			'simplec-' + LEFT(CAST(t.CustID AS VARCHAR), 3) + 
								CAST(s.DomainID AS VARCHAR(20)) +
								SUBSTRING(CAST(t.CustID AS VARCHAR), 4, LEN(CAST(t.CustID AS VARCHAR)) - 3) AS SubDomainPrefix,
			dbo.f_GetDateTime2()							
		FROM #tblCust t
			CROSS APPLY(SELECT TOP (1) * 
						FROM (SELECT Site,DomainID
							FROM @tmpDomain WHERE CashService = 1
							) d
						WHERE d.Site = t.Site
						) s
		WHERE t.cntDomain = 1
			AND NOT EXISTS (SELECT 1 FROM CashDomainManagement cdm WHERE cdm.AgentID = t.CustID AND cdm.DomainID = s.DomainID)
		
		-- Log all operations at the end
		DECLARE @TrackingValue NVARCHAR(MAX)
		DECLARE @CurrentAgentID INT
		DECLARE @CurrentAction VARCHAR(10)
		DECLARE @CurrentActionID INT
		DECLARE @RowCount INT = (SELECT COUNT(*) FROM @Operations)
		DECLARE @CurrentRow INT = 1
		
		-- Debug: Check if operations exist
		IF @RowCount > 0
		BEGIN
			WHILE @CurrentRow <= @RowCount
			BEGIN
				-- Debug: Check what's in the operations table
				-- SELECT * FROM @Operations WHERE RowID = @CurrentRow
				
				SELECT @TrackingValue = '<ROOT CustID="' + CONVERT(VARCHAR(20), AgentID) + '" IP="' + CONVERT(VARCHAR(50), @IP) + '" DomainId="' + CONVERT(VARCHAR(20), DomainID) + '" DomainName="' + ISNULL(DomainName, '') + '" />',
					   @CurrentAgentID = AgentID,
					   @CurrentAction = Action
				FROM @Operations 
				WHERE RowID = @CurrentRow
				
				-- Debug: Check if we got data
				IF @CurrentAgentID IS NOT NULL
				BEGIN
					SET @CurrentActionID = CASE WHEN @CurrentAction = 'Delete' THEN 31782 ELSE 31781 END
					
					EXEC GlobCustDB.dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
						@UserID = @UserID,
						@CustID = @CurrentAgentID,
						@ActionID = @CurrentActionID,
						@TrackingValue = @TrackingValue
				END
				
				SET @CurrentRow = @CurrentRow + 1
			END
		END
		
	END TRY
	BEGIN CATCH
		SELECT   @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE();		
		RETURN
	END CATCH
END	