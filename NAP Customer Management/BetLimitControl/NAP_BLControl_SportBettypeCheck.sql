/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_SportBettypeCheck] 
	@ProductList VARCHAR(200) = '',
	@SporttypeList VARCHAR(MAX) = '',
	@BettypeList VARCHAR(MAX) =  '',
	@LeagueGroupList VARCHAR(MAX) = '',
	@IsExcludedLeagueGroup BIT = 0,
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
		- 20211112@Eden: Alpha/NAP - In-house Replication (isDeleted & RepUpdateTime) [RedmineID: #164321]
		- 20220302@Johnson: Add league group [RedmineID: #156808]
		- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
		- 20220610@Tacy: Alpha/NAP - Remove IsDeleted field in League Table [RedmineID: #171699]
		- 20220617@Johnson: define temp table to avoid dump db [redmine:#174035]

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
	CREATE TABLE #Sport(ProductID TINYINT,Sporttype SMALLINT)
	CREATE TABLE #Bettype(ProductID TINYINT,Sporttype SMALLINT,Bettype SMALLINT)
	
	INSERT INTO #Sport(ProductID,Sporttype)
	SELECT DISTINCT 
		m.ProductID, 
		CASE WHEN @SporttypeList = '0' THEN m.sporttype ELSE sp.value END AS Sporttype	
	FROM DBEXT.bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN STRING_SPLIT(@ProductList,',') p1 ON m.ProductID = p1.value OR @ProductList = '0'
		LEFT JOIN STRING_SPLIT(@SporttypeList,',') sp ON m.Sporttype = sp.value OR @SporttypeList = '0'
	WHERE m.ProductID IN (SELECT ProductID FROM BetLimitControlProduct WITH(NOLOCK))
	
	INSERT INTO #Bettype(ProductID,Sporttype,Bettype)
	SELECT DISTINCT 
		m.ProductID,
		m.Sporttype,
		CASE WHEN @BettypeList = '0' THEN m.bettype ELSE bt.value END AS Bettype	
	FROM DBEXT.bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN #Sport s ON m.Sporttype = s.Sporttype
		LEFT JOIN STRING_SPLIT(@BettypeList,',') bt ON m.Bettype = bt.value OR @BettypeList = '0'
	WHERE m.ProductID IN (SELECT ProductID FROM BetLimitControlProduct WITH(NOLOCK))
	
	DECLARE @ErrorProducts VARCHAR(MAX) = '',
			@ErrorSporttypes VARCHAR(MAX) = '',
			@ErrorLeagueIDs VARCHAR(MAX) = '',
			@ErrorLeagueGroupIDs VARCHAR(MAX) = '' 			

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
	CREATE TABLE #League(LeagueID INT)
	CREATE TABLE #LeagueGroup(LeagueGroupID INT)	
	CREATE TABLE #SportLeague(Sporttype SMALLINT, LeagueID INT, LeagueGroupID INT)
	
	INSERT INTO #League(LeagueID)
	SELECT value AS LeagueID 	
	FROM STRING_SPLIT(@LeagueList,',') le
	WHERE value <> ''
	
	INSERT INTO #LeagueGroup(LeagueGroupID)	
	SELECT value AS LeagueGroupID 
	FROM STRING_SPLIT(@LeagueGroupList,',') lg
	WHERE value <> ''

	INSERT INTO #SportLeague(Sporttype,LeagueID,LeagueGroupID)
	SELECT l.Sporttype,l.LeagueID, l.LeagueGroupID	
	FROM DBPRO.bodb02.dbo.League l WITH(NOLOCK)
		INNER JOIN #League le ON l.LeagueID = le.LeagueID
		INNER JOIN #Sport s ON l.Sporttype = s.Sporttype
	WHERE s.ProductID = 1
	
	
	SELECT @ErrorLeagueGroupIDs = ''
		
	--> Invalid League Group ID: <ID1, ID2...>
	SELECT @ErrorLeagueGroupIDs = @ErrorLeagueGroupIDs + ', ' + CAST(lg.LeagueGroupID as VARCHAR(10))
	FROM #LeagueGroup lg		
	WHERE NOT EXISTS (SELECT 1 
						FROM DBPRO.bodb02.dbo.LeagueGroup lg2 WITH(NOLOCK)
						WHERE lg.LeagueGroupID = lg2.GroupID)		

	IF @ErrorLeagueGroupIDs <> ''
	BEGIN
		SELECT @ErrorLeagueGroupIDs = STUFF(@ErrorLeagueGroupIDs,1,2,'')
		SELECT @ErrorCode = 7,
			@ErrorMsg = 'Invalid League Group ID: ' + @ErrorLeagueGroupIDs + '.'

		RETURN
	END
	
	IF @IsExcludedLeagueGroup = 0 AND @LeagueGroupList <> ''
	BEGIN
		SELECT @ErrorSporttypes = ''
		
		--> None of the input league group belong to <Sport>.
		SELECT @ErrorSporttypes = @ErrorSporttypes + ', ' + s.SportName
		FROM #Sport sp
			INNER JOIN DBPRO.bodb02.dbo.sports s WITH(NOLOCK) ON sp.Sporttype = s.Sporttype			
		WHERE  sp.ProductID = 1 
			AND sp.Sporttype IS NOT NULL
			AND EXISTS (SELECT 1 
						FROM DBPRO.bodb02.dbo.League l WITH(NOLOCK)
						WHERE l.Sporttype=sp.Sporttype)
			AND NOT EXISTS (SELECT 1 
							FROM DBPRO.bodb02.dbo.League l WITH(NOLOCK)
							WHERE l.Sporttype=sp.Sporttype
							AND l.LeagueGroupID IN (SELECT LeagueGroupID FROM #LeagueGroup))		

		IF @ErrorSporttypes <> ''
		BEGIN
			SELECT @ErrorSporttypes = STUFF(@ErrorSporttypes,1,2,'')
			SELECT @ErrorCode = 8,
				@ErrorMsg = 'None of the input league group belong to ' + @ErrorSporttypes + '.'

			RETURN
		END
		
		--> League group <league group ID> belong to none of the selected sport.
		SELECT @ErrorLeagueGroupIDs = @ErrorLeagueGroupIDs + ', ' + lg.LeagueGroupID
		FROM #LeagueGroup lg			
		WHERE NOT EXISTS (SELECT 1
						FROM DBPRO.bodb02.dbo.League l WITH(NOLOCK)
							INNER JOIN #sport s ON l.sporttype = s.sporttype
						WHERE l.LeagueGroupID = lg.LeagueGroupID
						)
		
		IF @ErrorLeagueGroupIDs <> ''
			BEGIN
				SELECT @ErrorLeagueGroupIDs = STUFF(@ErrorLeagueGroupIDs,1,2,'')
				SELECT @ErrorCode = 9,
					@ErrorMsg = 'League Group '+ @ErrorLeagueGroupIDs + ' belong to none of the selected sport.' 

				RETURN
			END
			
	END
		
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
		SELECT @ErrorLeagueIDs = ''
		
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
		
		--League <league ID> belong to none of the selected league group.
		IF @IsExcludedLeagueGroup = 0 AND @LeagueGroupList <> ''
		BEGIN
			SELECT @ErrorLeagueIDs = ''
			
			SELECT @ErrorLeagueIDs = @ErrorLeagueIDs + ', ' + le.LeagueID
			FROM #League le
				INNER JOIN #SportLeague l ON le.LeagueID = l.LeagueID
				LEFT JOIN #LeagueGroup lg ON l.LeagueGroupID = lg.LeagueGroupID
			WHERE lg.LeagueGroupID IS NULL
			
			IF @ErrorLeagueIDs <> ''
			BEGIN
				SELECT @ErrorLeagueIDs = STUFF(@ErrorLeagueIDs,1,2,'')
				SELECT @ErrorCode = 11,
					@ErrorMsg = 'League '+ @ErrorLeagueIDs + ' belong to none of the selected league group.' 

				RETURN
			END
		END
	END
		
	INSERT INTO #ValidData(ProductID,Sporttype,Bettype,LeagueGroupID,LeagueID)
	SELECT DISTINCT 
		CASE WHEN @ProductList = '0' THEN 0 ELSE s.ProductID END AS ProductID,
		CASE WHEN @SporttypeList = '0' THEN 0 ELSE s.sporttype END AS sporttype,
		CASE WHEN @BettypeList = '0' THEN 0 ELSE bt.bettype END AS bettype,
		-1 AS LeagueGroupID,
		0 AS LeagueID
	FROM #Sport s 
		INNER JOIN #Bettype bt ON s.Sporttype = bt.Sporttype
	WHERE bt.Bettype IS NOT NULL AND s.ProductID <> 1
	UNION
	SELECT DISTINCT 
		CASE WHEN @ProductList = '0' THEN 0 ELSE s.ProductID END AS ProductID,
		CASE WHEN @SporttypeList = '0' THEN 0 ELSE s.sporttype END AS sporttype,
		CASE WHEN @BettypeList = '0' THEN 0 ELSE bt.bettype END AS bettype,
		CASE WHEN @IsExcludedLeagueGroup = 0 AND @LeagueGroupList <> '' THEN ISNULL(lg.LeagueGroupID,-1) ELSE -1 END AS LeagueGroupID,
		ISNULL(sl.LeagueID,0)  AS LeagueID
	FROM #Sport s 
		INNER JOIN #Bettype bt ON s.Sporttype = bt.Sporttype
		LEFT JOIN #SportLeague sl ON s.Sporttype = sl.Sporttype
		LEFT JOIN #LeagueGroup lg ON ISNULL(sl.LeagueGroupID,lg.LeagueGroupID) = lg.LeagueGroupID
	WHERE bt.Bettype IS NOT NULL AND s.ProductID = 1
	UNION
	select DISTINCT
	 CASE WHEN @ProductList = '0' THEN 0 ELSE s.ProductID END AS ProductID,
		CASE WHEN @SporttypeList = '0' THEN 0 ELSE s.sporttype END AS sporttype,
		CASE WHEN @BettypeList = '0' THEN 0 ELSE bt.bettype END AS bettype,
		CASE WHEN @IsExcludedLeagueGroup = 0 AND @LeagueGroupList <> '' THEN ISNULL(t.LeagueGroupID,-1) ELSE -1 END AS LeagueGroupID,
		0  AS LeagueID
	FROM #Sport s 
		INNER JOIN #Bettype bt ON s.Sporttype = bt.Sporttype
		INNER JOIN (SELECT DISTINCT lg.LeagueGroupID, l.sporttype
					FROM #LeagueGroup lg 
						INNER JOIN DBPRO.bodb02.dbo.League l WITH(NOLOCK) ON l.LeagueGroupID = lg.LeagueGroupID
					WHERE NOT EXISTS (SELECT 1 FROM #SportLeague l WHERE l.LeagueGroupID = lg.LeagueGroupID)) t	ON s.sporttype = t.sporttype
	WHERE bt.Bettype IS NOT NULL AND s.ProductID = 1
		AND @IsExcludedLeagueGroup = 0 
		AND @LeagueGroupList <> ''
	
	IF @ProductList = '0' AND @SporttypeList = '0' AND @BettypeList = '0' AND ISNULL(@LeagueList,'') <> ''
		DELETE 
		FROM #ValidData 
		WHERE ProductID = 0 
			AND Sporttype = 0 
			AND Bettype = 0 
			AND LeagueID = 0
	
	DROP TABLE #Bettype
	DROP TABLE #Sport
	DROP TABLE #League
	DROP TABLE #SportLeague	
	DROP TABLE #LeagueGroup
END
GO


