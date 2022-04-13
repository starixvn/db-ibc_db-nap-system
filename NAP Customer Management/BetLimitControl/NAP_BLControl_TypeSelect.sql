/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_TypeSelect] 
	@BetLimitTypeID INT = 0,
	@ProductID TINYINT = NULL,
	@Sporttype SMALLINT = NULL,
	@Bettype SMALLINT = NULL,
	@LiveIndicator	TINYINT = NULL,
	@UserId INT = 0,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - select Type Detail 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:
	-@LiveIndicator : 0 : NonLive , 1: Live , 2 : Both, 3 : All

	Example: 
	EXEC NAP_BLControl_TypeSelect 
		@ProductID = 0,
		@Sporttype = 0,
		@Bettype = 0,
		@LiveIndicator = 3,
		@UserId = 8

	*/
BEGIN
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey='CustomerManagement',
		@FunctionKey='BetLimitTypeControl',
		@Policy=1,
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		RETURN

	CREATE TABLE #BTC_SportBettypeReference(
		ProductID INT, 
		Sporttype INT, 
		Bettype   INT, 
		IsLive    BIT
		PRIMARY KEY (ProductID,Sporttype,Bettype,IsLive)
	)
	INSERT INTO #BTC_SportBettypeReference(ProductID,Sporttype,Bettype,IsLive)
	SELECT m.ProductID,m.Sporttype,m.Bettype,m.IsLive
	FROM DBEXT.bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK) 
		INNER JOIN DBEXT.bodb02.dbo.sports sp WITH(NOLOCK) ON m.Sporttype = sp.Sporttype
		INNER JOIN DBEXT.bodb02.dbo.Bettype s WITH(NOLOCK) ON m.Bettype = s.typeid
	WHERE ProductID IN (SELECT ProductID FROM BetLimitControlProduct WITH(NOLOCK))
	
	SELECT  BetLimitTypeID,
			BetLimitType,
			BeginTime,
			EndTime,
			LiveIndicator,
			RestrictVIP ,
			ProductList = SUBSTRING((	 SELECT ',' + CONVERT(VARCHAR,c.ProductID )
										 FROM #BTC_SportBettypeReference c
										 CROSS APPLY (	SELECT DISTINCT cast (1 as bit) AS Selected 
														FROM BetLimitControlTypeDetail b WITH(NOLOCK) 
														WHERE (b.ProductID = c.ProductID OR b.ProductID = 0)
															AND BetLimitTypeID = t.BetLimitTypeID) pro
										 GROUP BY c.ProductID
										 ORDER BY c.ProductID
										 FOR XML PATH ('')),2,10000),
			SportTypeList = SUBSTRING((  SELECT ',' + CONVERT(VARCHAR,SportType )
										 FROM #BTC_SportBettypeReference c
										 CROSS APPLY (	SELECT DISTINCT cast (1 as bit) AS Selected 
														FROM BetLimitControlTypeDetail b WITH(NOLOCK) 
														WHERE (b.Sporttype = c.Sporttype OR b.Sporttype = 0)
															AND (b.ProductID = c.ProductID OR b.ProductID = 0)
															AND BetLimitTypeID = t.BetLimitTypeID) sp
										 GROUP BY c.Sporttype
										 ORDER BY c.Sporttype
										 FOR XML PATH ('')),2,10000),
			BetTypeList = SUBSTRING((	SELECT ',' + CONVERT(VARCHAR,c.BetType)
										 FROM #BTC_SportBettypeReference c
										 CROSS APPLY (	SELECT DISTINCT cast (1 as bit) AS Selected 
														FROM BetLimitControlTypeDetail b WITH(NOLOCK) 
														WHERE (b.Bettype = c.Bettype OR b.Bettype = 0)
															AND (b.Sporttype = c.Sporttype OR b.Sporttype = 0)
															AND (b.ProductID = c.ProductID OR b.ProductID = 0)
															AND BetLimitTypeID = t.BetLimitTypeID) bt
										 GROUP BY c.BetType
										 ORDER BY c.Bettype
										 FOR XML PATH ('')),2,10000),
			LeagueGroupList = ISNULL(SUBSTRING((	 SELECT ',' + CONVERT(VARCHAR(10),b.leagueGroupID)
										 FROM BetLimitControlTypeDetail b WITH(NOLOCK) 
										 WHERE BetLimitTypeID = t.BetLimitTypeID AND LeagueGroupID <> -1
										 GROUP BY b.leagueGroupID
										 ORDER BY b.leagueGroupID
										 FOR XML PATH ('')),2,10000),''),
			ISNULL(ExcludedLeagueGroupList,'') ExcludedLeagueGroupList,								
			LeagueList = ISNULL(SUBSTRING((	 SELECT ',' + CONVERT(VARCHAR,b.leagueid)
										 FROM BetLimitControlTypeDetail b WITH(NOLOCK) 
										 WHERE BetLimitTypeID = t.BetLimitTypeID AND LeagueID <> 0
										 GROUP BY b.leagueid
										 ORDER BY b.leagueid
										 FOR XML PATH ('')),2,10000),''),
		IsAllProduct = CAST (0 AS BIT), 
		IsAllSporttype = CAST (0 AS BIT),
		IsAllBettype = CAST (0 AS BIT),
		IsAllLeague = CAST (0 AS BIT)
	INTO #BetLimitControlType
	FROM BetLimitControlType t WITH(NOLOCK)

	;WITH Temp AS (SELECT 
					IsAllProduct = MAX(CASE WHEN td.ProductID = 0 THEN 1 ELSE 0 END),
					IsAllSporttype = MAX(CASE WHEN td.Sporttype = 0 THEN 1 ELSE 0 END),
					IsAllBettype = MAX(CASE WHEN td.Bettype = 0 THEN 1 ELSE 0 END),
					IsAllLeague = MIN(CASE WHEN td.LeagueID > 0 THEN 0 ELSE 1 END),
					t.BetLimitTypeID
				FROM #BetLimitControlType t 
					INNER JOIN BetLimitControlTypeDetail td WITH(NOLOCK)
						ON t.BetLimitTypeID = td.BetLimitTypeID
				GROUP BY t.BetLimitTypeID
	)
	UPDATE bc
	SET IsAllProduct = t.IsAllProduct,
		IsAllSporttype = t.IsAllSporttype,
		IsAllBettype = t.IsAllBettype,
		IsAllLeague = t.IsAllLeague
	FROM #BetLimitControlType bc 
		INNER JOIN Temp t
			ON t.BetLimitTypeID = bc.BetLimitTypeID

	SELECT * 
	FROM #BetLimitControlType t
	WHERE (CHARINDEX( ',' +  CONVERT(VARCHAR,@ProductID) + ',',',' +  t.ProductList + ',') > 0 OR @ProductID = 0)
		AND (CHARINDEX( ',' +  CONVERT(VARCHAR,@Sporttype) + ',',',' +  t.SportTypeList + ',') > 0 OR @Sporttype = 0)
		AND (CHARINDEX( ',' +  CONVERT(VARCHAR,@Bettype) + ',',',' +  t.BetTypeList + ',') > 0 OR @Bettype = 0)
		AND (t.LiveIndicator = @LiveIndicator OR @LiveIndicator = 3)
		AND (t.BetLimitTypeID = @BetLimitTypeID OR @BetLimitTypeID = 0 )
	ORDER BY t.BetLimitType

	DROP TABLE #BTC_SportBettypeReference
	DROP TABLE #BetLimitControlType
END
GO


