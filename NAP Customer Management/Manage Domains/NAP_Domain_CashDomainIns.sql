/*<info serverAlias="DBCUST-AgencyCashService" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROC [dbo].[NAP_Domain_CashDomainIns]
	 @DomainList	NVARCHAR(MAX)
	,@ErrCode		INT=0			 OUTPUT
	,@ErrMsg		VARCHAR(2000)='' OUTPUT		
AS
/*
	Created: 20250625@Johnson
	Task: assign Agency Cash Service to Domain
	DB: DBCUST-AgencyCashService
	
	Revisions:	
		- 20250625@Johnson: offer Agency Cash Service [RedmineID: #231219]
	Param's Explanation:
		 @DomainList :
		 		<DomainList>
						<Domain id="111" s="1045,1046,1047,1048" />
						<Domain id="112" s="1050,1051,1052,1053" />
				</DomainList>
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tmpDomain TABLE (
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
		T.N.value('@s', 'VARCHAR(500)') AS Site
	FROM @xml.nodes('/DomainList/Domain') AS T(N)
	)
	INSERT INTO @tmpDomain (DomainID, SiteID)
	SELECT
        t.DomainID,
        TRIM(s.value) AS SiteID
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
			CROSS APPLY (SELECT TOP (2) * FROM @tmpDomain d WHERE d.Site = t.Site) s
		WHERE t.cntDomain = 0
		UNION 
		SELECT t.CustID, 
			s.DomainID, 
			'simplec-' + LEFT(CAST(t.CustID AS VARCHAR), 3) + 
								CAST(s.DomainID AS VARCHAR(20)) +
								SUBSTRING(CAST(t.CustID AS VARCHAR), 4, LEN(CAST(t.CustID AS VARCHAR)) - 3) AS SubDomainPrefix,
			dbo.f_GetDateTime2()							
		FROM #tblCust t
			CROSS APPLY (SELECT TOP (1) * FROM @tmpDomain d WHERE d.Site = t.Site) s
		WHERE t.cntDomain = 1
	END TRY
	BEGIN CATCH
		SELECT   @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE();		
		RETURN
	END CATCH	

END	