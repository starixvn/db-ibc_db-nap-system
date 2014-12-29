ALTER PROCEDURE [dbo].[NAP_CustSettingControl_ViolatedSMASelect]
	@Username			NVARCHAR(50)= NULL,
	@SiteID				NVARCHAR(50)= NULL,
	@Currency			INT			= NULL,
	@Status				TINYINT		= NULL,
	@GroupHeadLineID	INT			= NULL,
	@RoleID				TINYINT		= NULL
AS 
/*	Created by: Dominic
	Date: 20141224
	Task: Display a list of violated PotsitonTaking Policy SMA
	DB: DBACC/bodb02
	*Parameters:
		- @Status: 4-Open 3-Suspended 2-Closed 1-Disabled
		- @GroupHeadLineID: CustID of headline customer, 0-Not assigned to any group
	*Revisions:
		
*/
BEGIN	
	SET NOCOUNT ON

	CREATE TABLE #DirectCusts (
		CustID				INT
		,RoleID				TINYINT
		,Username			NVARCHAR(50)
		,[Site]				NVARCHAR(50)
		,SiteID				INT
		,Currency			INT
		,CurrencyName		NVARCHAR(50)
		,IsGrouped			BIT DEFAULT(0)
		,GroupID			SMALLINT DEFAULT(0)
		,GroupHeadlineID	INT
		,GroupHeadlineName	NVARCHAR(50) DEFAULT('No group')
		,[Status]			SMALLINT
		,IsEnabled			BIT
		,IsClosed			BIT
		,IsRejected			BIT
		)
	
	DECLARE @GroupInfo TABLE(
		GroupID SMALLINT,
		GroupHeadLineID INT,
		GroupHeadLineName NVARCHAR(50)
	)	
		
	DECLARE @DepositDummySuper TABLE  (
			CustID INT
		)
	
	CREATE TABLE #SportBetTypeMapping (
		SportType			SMALLINT
		,BetType			SMALLINT
		,ProductID			TINYINT DEFAULT(1)
	)
	
	DECLARE @ViolatedSetting TABLE(
		CustID				INT
		,ProductID			TINYINT
		,SuperMax			SMALLMONEY
		,MasterMax			SMALLMONEY
		,AgentMax			SMALLMONEY
	)


	--Get deposit and dummy Super	
	INSERT INTO @DepositDummySuper
	SELECT custid FROM dbo.Dep_CustSuper
	UNION
	SELECT custid FROM dbo.Acc_CustDirect WHERE roleid = 4

	--Get Real Credit Super/Direct Master/Direct Agent
	INSERT INTO #DirectCusts(CustID,Site)
	SELECT-- Super
		cust.custid,cust.site
	FROM  dbo.Customer cust WITH(NOLOCK)  
	INNER JOIN dbo.CustSuper cs WITH(NOLOCK) ON cust.custid = cs.custid AND cs.IsInternal = 0	
	LEFT JOIN @DepositDummySuper dd ON dd.CustID = cust.CustID
	WHERE cust.roleid = 4 AND cust.currency NOT IN (20 ,27 , 28) AND dd.CustID IS NULL
	UNION ALL --Get Direct Master Accounts
	SELECT 
		cust.custid,cust.site
	FROM dbo.Acc_CustDirect acccust  WITH(NOLOCK)  
	INNER JOIN customer cust WITH(NOLOCK) ON  acccust.custid = cust.srecommEND  AND acccust.roleid = 4 AND cust.roleid = 3   
	INNER JOIN custmaster cm WITH(NOLOCK) ON  cm.custid = cust.custid AND cm.isINTernal = 0 
	LEFT JOIN dbo.Acc_CustDirect cdr ON cdr.CustID = cust.CustID AND cdr.RoleID=3 
	WHERE cust.currency NOT IN (20,27,28) AND cdr.custid IS NULL
	UNION ALL --Get Direct Agent Accounts
	SELECT 
		cust.custid,cust.site
	FROM dbo.Acc_CustDirect acccust  WITH(NOLOCK)  
	INNER JOIN customer cust WITH(NOLOCK) ON  acccust.custid = cust.mrecommEND  AND acccust.roleid = 3 AND cust.roleid = 2  
	INNER JOIN custagent ca WITH(NOLOCK) ON  ca.custid = cust.custid AND ca.isINTernal = 0  
	LEFT JOIN dbo.Acc_CustDirect cdr ON cdr.CustID = cust.CustID AND cdr.RoleID=2
	WHERE cust.currency NOT IN (20,27,28) AND cdr.custid IS NULL
	
	CREATE CLUSTERED INDEX IDX_CustID ON #DirectCusts(CustID)
	
	--Get more general customer information
	UPDATE main
	SET
		main.RoleID = ci.RoleID
		,main.Username = ci.username
		,main.Currency = ci.currency
		,main.IsEnabled = ci.enabled
		,main.IsClosed = ci.closed
		,main.IsRejected = ci.reject
	FROM #DirectCusts main
	JOIN dbo.CustInfo ci WITH(NOLOCK) ON main.CustID = ci.CustID
	
	--Get siteID
	UPDATE main
	SET main.SiteID = s.SiteID
	FROM #DirectCusts main
	JOIN dbo.Site s ON main.Site = s.Site
	
	--Filetered by @username
	IF @Username IS NOT NULL
	BEGIN
		DELETE FROM #DirectCusts
		WHERE Username NOT LIKE '%' + @Username + '%'
	END
	
	--Filetered by @Site
	IF @SiteID IS NOT NULL
	BEGIN
		DELETE FROM #DirectCusts
		WHERE SiteID <>  @SiteID
	END
	
	--Filetered by @Currency
	IF @Currency IS NOT NULL
	BEGIN
		DELETE FROM #DirectCusts
		WHERE Currency <>  @Currency
	END
	
	--Filetered by @RoleID
	IF @RoleID IS NOT NULL
	BEGIN
		DELETE FROM #DirectCusts
		WHERE RoleID <>  @RoleID
	END
	
	--Update status
	UPDATE #DirectCusts
	SET [status] =  CASE WHEN IsEnabled = 0 THEN 1
						 WHEN IsEnabled = 1 AND IsClosed = 1 THEN 2
						 WHEN IsEnabled = 1 AND IsClosed = 0 AND IsRejected = 1 THEN 3
						 ELSE 4
					END
	
	--Filetered by @Status
	IF @Status IS NOT NULL
	BEGIN
		DELETE FROM #DirectCusts
		WHERE [Status] = @Status
	END
	
	--Update GroupHeadline Information
	UPDATE main
	SET
		main.GroupID = ca.GroupID
		,main.IsGrouped = 1
	FROM #DirectCusts main
	JOIN dbo.custaccount ca WITH(NOLOCK)
			ON main.CustID = ca.CustID
	WHERE ca.groupID <> 0
	
	INSERT @GroupInfo
	SELECT ca.groupid,ca.custid ,ci.username
	FROM custaccount ca WITH(NOLOCK)
	JOIN dbo.CustInfo ci WITH(NOLOCK) ON ci.CustID = ca.CustID
	WHERE isgroupheadline=1 AND groupID <> 0
	
	
	--Update Group Headline Name
	UPDATE main
	SET
		main.GroupHeadlineID = gi.GroupHeadlineID
		,main.GroupHeadlineName = gi.GroupHeadlineName
	FROM #DirectCusts main
	JOIN @GroupInfo gi ON gi.GroupID = main.GroupID
	
	--Update status for Groups that do not have headline
	UPDATE #DirectCusts
	SET IsGrouped = 0 
	WHERE IsGrouped=1 AND GroupHeadlineID IS NULL
	
	--Filetered by @GroupHeadLineID
	IF @GroupHeadLineID IS NOT NULL
	BEGIN
		DELETE FROM #DirectCusts
		WHERE GroupHeadlineID = @GroupHeadLineID
	END
	
	--Update currency name
	UPDATE main
	SET main.CurrencyName = e.currency
	FROM #DirectCusts main
	JOIN Exchange e WITH(NOLOCK) ON e.exchangeid = main.currency
	
	--Create Sporttype/Bettype mapping data
	DECLARE @CustID INT
	SELECT TOP 1 @CustID = CustID
	FROM dbo.CustSetting  WITH(NOLOCK)
	ORDER BY CustID DESC

	INSERT #SportBetTypeMapping(SportType,BetType)
	SELECT SportType,BetType FROM dbo.CustSetting WITH(NOLOCK) WHERE CustID=@CustID
	UNION ALL
	SELECT SportType,BetType FROM dbo.CustSetting3rd WITH(NOLOCK) WHERE CustID=@CustID
	UNION ALL
	SELECT SportType,BetType FROM dbo.custsettingGame WITH(NOLOCK) WHERE CustID=@CustID
	
	--RC
	UPDATE #SportBetTypeMapping
	SET ProductID = 2
	WHERE SportType BETWEEN 151 AND 153
	
	--NG
	UPDATE #SportBetTypeMapping
	SET ProductID = 3
	WHERE SportType=161 AND BetType BETWEEN 81 and 120
	
	--LC
	UPDATE #SportBetTypeMapping
	SET ProductID = 4
	WHERE SportType = 162 AND BetType = 1101
	
	--VS
	UPDATE #SportBetTypeMapping
	SET ProductID = 5
	WHERE SportType IN (180,181,182,183,184,185,186) AND BetType IN (1201 , 1231, 1220)
	
	--KN
	UPDATE #SportBetTypeMapping
	SET ProductID = 8
	WHERE BetType BETWEEN 1501 AND 1599 AND SportType = 202
	
	CREATE CLUSTERED INDEX IDX_sporttype_bettype ON #SportBetTypeMapping(sporttype,bettype)
	
	--SB - Deadball
	INSERT @ViolatedSetting
	SELECT main.CustID,p.ProductID
		,cs.spositiontaking SuperMax
		,cs.mpositiontaking MasterMax
		,cs.apositiontaking AgentMax
	FROM dbo.CustSetting cs
	JOIN #DirectCusts main ON main.CustID = cs.CustID
	JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
	JOIN dbo.PTSettingPolicy p
		ON p.SiteID = main.SiteID
			AND p.ExchangeID = main.Currency
			AND p.RoleID = main.RoleID
			AND p.ProductID = mp.ProductID
	WHERE (p.AgentMax IS NOT NULL AND cs.apositiontaking <> p.AgentMax)
			OR (p.MasterMax IS NOT NULL AND cs.mpositiontaking  <> p.MasterMax)
			OR (p.SuperMax IS NOT NULL AND cs.spositiontaking <> p.SuperMax)
	
			
	--SB - Liveball
	INSERT @ViolatedSetting
	SELECT main.CustID,p.ProductID
		,cs.slivepositiontaking SuperMax
		,cs.mlivepositiontaking MasterMax
		,cs.alivepositiontaking AgentMax
	FROM dbo.CustSetting cs
	JOIN #DirectCusts main ON main.CustID = cs.CustID
	JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
	JOIN dbo.PTSettingPolicy p
		ON p.SiteID = main.SiteID
			AND p.ExchangeID = main.Currency
			AND p.RoleID = main.RoleID
			AND p.ProductID = mp.ProductID
	WHERE ((p.AgentMax IS NOT NULL AND cs.alivepositiontaking <> p.AgentMax)
			OR (p.MasterMax IS NOT NULL AND cs.mlivepositiontaking  <> p.MasterMax)
			OR (p.SuperMax IS NOT NULL AND cs.slivepositiontaking <> p.SuperMax))
			AND cs.SportType=1 AND cs.BetType IN (1,3,7,8)
		  
	--NG(Deadball),RC,VS
	INSERT @ViolatedSetting
	SELECT main.CustID,p.ProductID
		,cs.spositiontaking SuperMax
		,cs.mpositiontaking MasterMax
		,cs.apositiontaking AgentMax
	FROM dbo.CustSetting3rd cs
	JOIN #DirectCusts main ON main.CustID = cs.CustID
	JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
	JOIN dbo.PTSettingPolicy p
		ON p.SiteID = main.SiteID
			AND p.ExchangeID = main.Currency
			AND p.RoleID = main.RoleID
			AND p.ProductID = mp.ProductID
	WHERE (p.AgentMax IS NOT NULL AND cs.apositiontaking <> p.AgentMax)
			OR (p.MasterMax IS NOT NULL AND cs.mpositiontaking  <> p.MasterMax)
			OR (p.SuperMax IS NOT NULL AND cs.spositiontaking <> p.SuperMax)
			
	--NG - Liveball
	INSERT @ViolatedSetting
	SELECT main.CustID,p.ProductID
		,cs.slivepositiontaking SuperMax
		,cs.mlivepositiontaking MasterMax
		,cs.alivepositiontaking AgentMax
	FROM dbo.CustSetting3rd cs
	JOIN #DirectCusts main ON main.CustID = cs.CustID
	JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
	JOIN dbo.PTSettingPolicy p
		ON p.SiteID = main.SiteID
			AND p.ExchangeID = main.Currency
			AND p.RoleID = main.RoleID
			AND p.ProductID = mp.ProductID
	WHERE ((p.AgentMax IS NOT NULL AND cs.alivepositiontaking <> p.AgentMax)
			OR (p.MasterMax IS NOT NULL AND cs.mlivepositiontaking  <> p.MasterMax)
			OR (p.SuperMax IS NOT NULL AND cs.slivepositiontaking <> p.SuperMax))
			AND cs.SportType=161 AND cs.BetType IN (85,86,87,89,90)

	--LC,KN
	INSERT @ViolatedSetting
	SELECT main.CustID,p.ProductID
		,cs.spositiontaking SuperMax
		,cs.mpositiontaking MasterMax
		,cs.apositiontaking AgentMax
	FROM dbo.CustSettingGame cs
	JOIN #DirectCusts main ON main.CustID = cs.CustID
	JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
	JOIN dbo.PTSettingPolicy p
		ON p.SiteID = main.SiteID
			AND p.ExchangeID = main.Currency
			AND p.RoleID = main.RoleID
			AND p.ProductID = mp.ProductID
	WHERE (p.AgentMax IS NOT NULL AND cs.apositiontaking <> p.AgentMax)
			OR (p.MasterMax IS NOT NULL AND cs.mpositiontaking  <> p.MasterMax)
			OR (p.SuperMax IS NOT NULL AND cs.spositiontaking <> p.SuperMax)
		
	
	--Get serious violated PT settings to be displayed		
	SELECT custid,ProductID,MAX(SuperMax) SuperMax,MAX(MasterMax) MasterMax,MAX(AgentMax) AgentMax
	INTO #MaxViolatedSetting
	FROM @ViolatedSetting
	GROUP BY custid,ProductID
	
	CREATE CLUSTERED INDEX IDX_sporttype_bettype ON #MaxViolatedSetting(custid,ProductID)
	
	
	--List of violated CustID
	SELECT DISTINCT CustID
	INTO #ViolatedCustIDs
	FROM @ViolatedSetting
	
	
	--Sum Final results
	SELECT IsGrouped
		,c.GroupHeadlineName
		,c.CustID
		,c.Username
		,c.Status
		,c.SiteID
		,c.site
		,c.Currency
		,c.CurrencyName
		,c.RoleID
		,p.ProductID
		,CASE WHEN p.SuperMax <> v.SuperMax THEN v.SuperMax ELSE p.SuperMax END SuperMax
		,CASE WHEN p.SuperMax <> v.SuperMax THEN 1 ELSE 0 END SDiff
		,CASE WHEN p.MasterMax <> v.MasterMax THEN v.MasterMax ELSE p.MasterMax END MasterMax
		,CASE WHEN p.MasterMax <> v.MasterMax THEN 1 ELSE 0 END MDiff
		,CASE WHEN p.AgentMax <> v.AgentMax THEN v.AgentMax ELSE p.AgentMax END AgentMax
		,CASE WHEN p.AgentMax <> v.AgentMax THEN 1 ELSE 0 END ADiff
		,0 IsDisabled
	INTO #FinalResult
	FROM #DirectCusts c
	JOIN #ViolatedCustIDs f ON c.CustID = f.CustID
	JOIN dbo.PTSettingPolicy p
		ON p.SiteID = c.SiteID
		AND p.ExchangeID = c.Currency
		AND p.RoleID = c.RoleID
	LEFT JOIN #MaxViolatedSetting v
		ON 	v.ProductID = p.ProductID
			AND v.CustID = c.CustID
	
	--Update Product Status
	UPDATE main
	SET
		main.IsDisabled = CASE
								WHEN main.ProductID = 2 THEN (ci.Disable151_AU & ci.Disable152_AU & ci.Disable152_UK & ci.Disable153_AU & ci.DisableHorseRacing & ci.DisableOpenTote)
								WHEN main.ProductID = 3 THEN ci.DisableNumber
								WHEN main.ProductID = 4 THEN (~ci.SyncLiveCasino | ci.DisableLiveCasino)
								WHEN main.ProductID = 5 THEN ci.DisableVirtualSports
							END
	FROM #FinalResult main
	JOIN dbo.CustInfo ci ON ci.CustID = main.CustID
	WHERE main.ProductID IN (2,3,4,5)
	
	--Update Keno's status
	UPDATE main
	SET
		main.IsDisabled = CASE WHEN EXISTS(SELECT TOP 1 1 FROM dbo.CustGameType gt WITH(NOLOCK)
																					WHERE gt.CustID = main.CustID AND gt.IsDisabled = 0 ) 
																					THEN 0 
																					ELSE 1 
																					END
	FROM #FinalResult main 
	WHERE main.ProductID = 8
	
	
	--Return Result
	SELECT GroupHeadlineName
		, CustID
		, Username
		, Status
		, SiteID
		, Site
		, Currency
		, CurrencyName
		, RoleID
		, ProductID
		, SuperMax
		, SDiff
		, MasterMax
		, MDiff
		, AgentMax
		, ADiff
		, IsDisabled
	FROM #FinalResult
	ORDER BY IsGrouped,GroupHeadlineName,Username, Status DESC , ProductID
	
	
	DROP TABLE #MaxViolatedSetting
	DROP TABLE #SportBetTypeMapping
	DROP TABLE #ViolatedCustIDs
	DROP TABLE #DirectCusts
	DROP TABLE #FinalResult
END
