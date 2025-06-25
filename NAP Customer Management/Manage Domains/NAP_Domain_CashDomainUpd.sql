/*<info serverAlias="DBCUST-AgencyCashService" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROC [dbo].[NAP_Domain_CashDomainUpd]
	 @DomainList	NVARCHAR(MAX)
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
						<Domain id="111" s="1045,1046" cs="1"/>
						<Domain id="111" s="1050,1051" cs="0"/>
						<Domain id="112" s="1047,1048" cs="0"/>
						<Domain id="113" s="1052,1053" cs="1"/>
				</DomainList>
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tmpDomain TABLE (
			 DomainID		SMALLINT
			,SiteID			INT
			,CashService	BIT
			,Site 			VARCHAR(50)
	)

	--active domains remaining for site removed
	DECLARE @tmpDomainActive TABLE (
			 DomainID		SMALLINT
			,SiteID			INT	
			,Site 			VARCHAR(50)		
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
		T.N.value('@s', 'VARCHAR(500)') AS Site,
		T.N.value('@cs', 'BIT') AS CashService
	FROM @xml.nodes('/DomainList/Domain') AS T(N)
	)
	INSERT INTO @tmpDomain (DomainID, SiteID, CashService)
	SELECT
        t.DomainID,
        TRIM(s.value) AS SiteID,
        t.CashService
    FROM T
    CROSS APPLY STRING_SPLIT(t.Site, ',') s
	
	UPDATE t
	SET t.Site = s.Site
	FROM @tmpDomain t
	INNER JOIN CustDB.dbo.Site s WITH(NOLOCK) ON s.SiteID = t.siteid

	INSERT INTO #tblCust (CustID, Site)
	SELECT c.custid, c.site
	FROM CustDB.dbo.customer c WITH(NOLOCK)
		CROSS APPLY (SELECT TOP 1 custid FROM  CustDB.dbo.CustProductStatus cs WITH(NOLOCK) WHERE cs.CustID = c.CustID AND cs.ServiceType = 1) t
	WHERE roleid = 2
		AND site IN (SELECT site FROM @tmpDomain)		

	--remove customer have site turn off domain
	IF EXISTS (SELECT 1 FROM @tmpDomain WHERE CashService = 0)
	BEGIN
		DELETE d 
		FROM CashDomainManagement d WITH(ROWLOCK)
		WHERE EXISTS (SELECT 1 
						FROM #tblCust t
						CROSS APPLY (SELECT * FROM @tmpDomain td WHERE td.Site = t.Site AND CashService = 0) s						
					WHERE t.custid = d.AgentID
						AND s.DomainID = d.DomainID)	

		INSERT INTO @tmpDomainActive (DomainID, SiteID)
		SELECT DomainID, SiteID
		FROM GlobCustDB.dbo.DomainManagement d WITH(NOLOCK)
			CROSS APPLY (SELECT CAST(TRIM(value) AS INT) SiteID FROM STRING_SPLIT(d.Site, ',')) s
		WHERE Status = 3
			AND d.IsDeleted = 0
			AND d.OfferType = 1
			AND s.SiteID IN (SELECT SiteID FROM @tmpDomain WHERE CashService = 0)

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
							UNION 
							SELECT Site,DomainID
							FROM @tmpDomainActive 
							) d
						WHERE d.Site = t.Site
						) s
		WHERE t.cntDomain = 0
		UNION 
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
							UNION 
							SELECT Site,DomainID
							FROM @tmpDomainActive 
							) d
						WHERE d.Site = t.Site
						) s
		WHERE t.cntDomain = 1
	END TRY
	BEGIN CATCH
		SELECT   @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE();		
		RETURN
	END CATCH	

END	