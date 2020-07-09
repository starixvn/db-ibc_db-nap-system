/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_SportBettypeCheck] 
	@ProductList VARCHAR(200) = '',
	@SporttypeList VARCHAR(MAX) = '',
	@BettypeList VARCHAR(MAX) =  '',
	@LeagueGroupList VARCHAR(MAX) = '',
	@LeagueList VARCHAR(MAX) =  '',
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(MAX) = '' OUTPUT 
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - Insert new Type 
	DB: DBCUST-CUSTDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:
	- @ErrorCode: 
		1: The bet limit type exist already.

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(MAX) = '' 
	EXEC NAP_BLControl_SportBettypeCheck 
		@ProductList = '0',
		@SporttypeList = '0',
		@BettypeList = '0',
		@LeagueGroupList = '',
		@LeagueList =  '',
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	SELECT DISTINCT 
		m.ProductID, 
		CASE WHEN @SporttypeList = '0' THEN m.sporttype ELSE sp.val END AS Sporttype
	INTO #Sport
	FROM DBEXT.bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN dbo.f_StringSplit(@ProductList,',') p1 ON m.ProductID = p1.val OR @ProductList = '0'
		LEFT JOIN dbo.f_StringSplit(@SporttypeList,',') sp ON m.Sporttype = sp.val OR @SporttypeList = '0'
	WHERE m.ProductID IN (SELECT ProductID FROM BetLimitControlProduct WITH(NOLOCK))
	OPTION (MAXRECURSION 0)

	SELECT DISTINCT 
		m.ProductID,
		m.Sporttype,
		CASE WHEN @BettypeList = '0' THEN m.bettype ELSE bt.val END AS Bettype
	INTO #Bettype
	FROM DBEXT.bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN dbo.f_StringSplit(@SporttypeList,',') p1 ON m.Sporttype = p1.val OR @SporttypeList = '0'
		LEFT JOIN dbo.f_StringSplit(@BettypeList,',') bt ON m.Bettype = bt.val OR @BettypeList = '0'
	WHERE m.ProductID IN (SELECT ProductID FROM BetLimitControlProduct WITH(NOLOCK))
	OPTION (MAXRECURSION 0)

	DECLARE @ErrorProducts VARCHAR(MAX) = '',
			@ErrorSporttypes VARCHAR(MAX) = '',
			@ErrorLeagueIDs VARCHAR(MAX) = '' 

	--> <Product> has no sport.
	SELECT @ErrorProducts = @ErrorProducts + ', ' + MAX(p.ProductName) --+ CONVERT(VARCHAR,s.ProductID)   
	FROM #Sport s
		INNER JOIN DBPRO.bodb02.dbo.products p WITH(NOLOCK) ON s.ProductID = p.ProductID
	GROUP BY s.ProductID
	HAVING SUM(CASE WHEN s.Sporttype IS NOT NULL THEN 1 ELSE 0 END) = 0

	IF @ErrorProducts <> ''
	BEGIN
		SELECT @ErrorProducts = STUFF(@ErrorProducts,1,2,'')
		SELECT @ErrorCode = 2,
			@ErrorMsg = @ErrorProducts + ' has no sport.'

		RETURN
	END
	
	--><Sport> has no bet type.
	SELECT @ErrorSporttypes = @ErrorSporttypes + ', ' + MAX(s.SportName)  
	FROM #Bettype bt
		INNER JOIN DBPRO.bodb02.dbo.sports s WITH(NOLOCK) ON bt.Sporttype = s.Sporttype
	GROUP BY bt.Sporttype
	HAVING SUM(CASE WHEN bt.Bettype IS NOT NULL THEN 1 ELSE 0 END) = 0

	IF @ErrorSporttypes <> ''
	BEGIN
		SELECT @ErrorSporttypes = STUFF(@ErrorSporttypes,1,2,'')
		SELECT @ErrorCode = 3,
			@ErrorMsg = @ErrorSporttypes + ' has no bet type.'

		RETURN
	END

	SELECT val AS LeagueID 
	INTO #League
	FROM dbo.f_StringSplit(@LeagueList,',') le
	OPTION (MAXRECURSION 0)

	SELECT l.Sporttype,l.LeagueID
	INTO #SportLeague
	FROM DBPRO.bodb02.dbo.League l WITH(NOLOCK)
		INNER JOIN #League le ON l.LeagueID = le.LeagueID
		INNER JOIN #Sport s ON l.Sporttype = s.Sporttype
	WHERE s.ProductID = 1

	IF ISNULL(@LeagueList,'') <> ''
	BEGIN
		--> None of the input league belong to <Sport>.
		SELECT @ErrorSporttypes = @ErrorSporttypes + ', ' + MAX(s.SportName)
		FROM #Sport sp
			INNER JOIN DBPRO.bodb02.dbo.sports s WITH(NOLOCK) ON sp.Sporttype = s.Sporttype
			LEFT JOIN #SportLeague l ON sp.Sporttype = l.Sporttype
		WHERE  sp.ProductID = 1 
			AND sp.Sporttype IS NOT NULL
			AND l.Sporttype IS NULL
		GROUP BY sp.Sporttype

		IF @ErrorSporttypes <> ''
		BEGIN
			SELECT @ErrorSporttypes = STUFF(@ErrorSporttypes,1,2,'')
			SELECT @ErrorCode = 4,
				@ErrorMsg = 'None of the input league belong to ' + @ErrorSporttypes + '.'

			RETURN
		END

		--> League <league ID> belong to none of the selected sport.
		SELECT @ErrorLeagueIDs = @ErrorLeagueIDs + ', ' + le.LeagueID
		FROM #League le
			LEFT JOIN #SportLeague l ON le.LeagueID = l.LeagueID
		WHERE l.LeagueID IS NULL

		IF @ErrorLeagueIDs <> ''
		BEGIN
			SELECT @ErrorLeagueIDs = STUFF(@ErrorLeagueIDs,1,2,'')
			SELECT @ErrorCode = 5,
				@ErrorMsg = 'League '+ @ErrorLeagueIDs + ' belong to none of the selected sport.' 

			RETURN
		END
	END

	INSERT INTO #ValidData(ProductID,Sporttype,Bettype,LeagueGroupID,LeagueID)
	SELECT DISTINCT 
		CASE WHEN @ProductList = '0' THEN 0 ELSE s.ProductID END AS ProductID,
		CASE WHEN @SporttypeList = '0' THEN 0 ELSE s.sporttype END AS sporttype,
		CASE WHEN @BettypeList = '0' THEN 0 ELSE bt.bettype END AS bettype,
		0 AS LeagueGroupID,
		0 AS LeagueID
	FROM #Sport s 
		INNER JOIN #Bettype bt ON s.Sporttype = bt.Sporttype
	WHERE bt.Bettype IS NOT NULL AND s.ProductID <> 1
	UNION
	SELECT DISTINCT 
		CASE WHEN @ProductList = '0' THEN 0 ELSE s.ProductID END AS ProductID,
		CASE WHEN @SporttypeList = '0' THEN 0 ELSE s.sporttype END AS sporttype,
		CASE WHEN @BettypeList = '0' THEN 0 ELSE bt.bettype END AS bettype,
		0 AS LeagueGroupID,
		ISNULL(sl.LeagueID,0)  AS LeagueID
	FROM #Sport s 
		INNER JOIN #Bettype bt ON s.Sporttype = bt.Sporttype
		LEFT JOIN #SportLeague sl ON s.Sporttype = sl.Sporttype
	WHERE bt.Bettype IS NOT NULL AND s.ProductID = 1

	DROP TABLE #Bettype
	DROP TABLE #Sport
	DROP TABLE #League
	DROP TABLE #SportLeague
END
GO


