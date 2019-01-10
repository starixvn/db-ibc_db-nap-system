/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_Rpt_CreditCollection]
	@Code			VARCHAR(30) = '',
	@Status			VARCHAR(20) = '0,1', 
	@Type			SMALLINT = 2,
	@ExcludeTest	BIT = 0,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME, 
	@BalanceUpDay	SMALLDATETIME,
	@pageIndex	INT = 1,
	@pageSize	INT = 100,
	@totalItems INT = 0 OUTPUT
AS
 
/*  Created: Sophia  
	Date:	20181206
	DB:		DBACC.bodb02 
	Task :  Report Credit Collection [Redmine: 98621]
	
	Param's Explanation:  

		@Code:	GroupName (username) search exactly ,  '' is all
		@Status: String , multiple choice
			(0: Normal, 1: Alert, 2: Unused)						 
		@Type: All = 2
			   OLD Codes = 1
			   Others Codes = 0

	Revisions:  
	- 20181206@Sophia: initial SP
 
*/

BEGIN 
	SET NOCOUNT ON 
	
	DECLARE @RowStart int, @RowEnd int	
		
	SELECT	@PageIndex = @PageIndex - 1, 
			@RowStart = @PageSize * @PageIndex + 1, 
			@RowEnd = @RowStart + @PageSize - 1 

			

	DECLARE @HasBT_BK BIT = 0, 
			@HasBT_14 BIT = 0, 
			@HasBT BIT = 0

	DECLARE @FromDateBT_BK SMALLDATETIME = NULL, 
			@ToDateBT_BK SMALLDATETIME = NULL, 
			@FromDateBT_14 SMALLDATETIME = NULL, 
			@ToDateBT_14 SMALLDATETIME = NULL, 
			@FromDateBT SMALLDATETIME = NULL, 
			@ToDateBT SMALLDATETIME = NULL

	---- Detect range data
	IF @FromDate < @BalanceUpDay 
		BEGIN 			
			
			SELECT @HasBT_BK = 1

			SELECT @FromDateBT_BK = @FromDate

			IF @ToDate < @BalanceUpDay 
			BEGIN 				
				SELECT @ToDateBT_BK = @ToDate					
			END
			ELSE
			BEGIN 
				SELECT @ToDateBT_BK = DATEADD (DD,-1,@BalanceUpDay)
			END
		END

	IF ( @FromDate <= @MoveBetsDay) AND (@ToDate >= @BalanceUpDay ) 
		BEGIN 		
			
			SELECT @HasBT_14 = 1

			IF @FromDate <= @BalanceUpDay 
			BEGIN 				
				SELECT @FromDateBT_14 = @BalanceUpDay					
			END
			ELSE
			BEGIN 
				SELECT @FromDateBT_14 = @FromDate
			END

			IF @ToDate >= @MoveBetsDay 
			BEGIN 				
				SELECT @ToDateBT_14 = @MoveBetsDay 				
			END
			ELSE
			BEGIN 
				SELECT @ToDateBT_14 = @ToDate
			END
		END

	IF @ToDate > @MoveBetsDay 
		BEGIN 			
			
			SELECT @HasBT = 1

			SELECT @ToDateBT = @ToDate

			IF @FromDate > @MoveBetsDay 
			BEGIN 				
				SELECT @FromDateBT = @FromDate 				
			END
			ELSE
			BEGIN 
				SELECT @FromDateBT =  DATEADD (DD, 1, @MoveBetsDay)	
			END
		END


	/* 1. Group Headline and Direct Account Table*/
	CREATE TABLE #GroupHeadLineAll
	(
		--RowId			INT IDENTITY(1,1) PRIMARY KEY,
		CustId			INT,
		Username		VARCHAR(30),
		Coll_Status		TINYINT,
		IsGroupHeadLine BIT,
		GroupID			INT
	)	

	CREATE TABLE #GroupHeadLine 
	(
		--RowId			INT IDENTITY(1,1) PRIMARY KEY,
		CustId			INT,
		Username		VARCHAR(30),
		Coll_Status		TINYINT,
		IsGroupHeadLine BIT,
		GroupID			INT
	)	
	
	INSERT INTO #GroupHeadLineAll   (CustId, Username, Coll_Status, IsGroupHeadLine, GroupID)
	SELECT	D.CustId AS CustId, C.Username , D.Coll_Status AS Coll_Status, 
			CASE WHEN ISNULL(G.GroupID,0) = 0 THEN 0 ELSE 1 END AS IsGroupHeadLine, 
			CASE WHEN ISNULL(G.GroupID,0) = 0 THEN D.CustId ELSE G.GroupID END AS GroupID				
	FROM dbo.CustDirectAccount D WITH (NOLOCK)
		 INNER JOIN dbo.Customer C WITH (NOLOCK) ON C.CustID = D.CustID
		 LEFT JOIN dbo.custAccount G WITH (NOLOCK) ON G.CustID = D.CustID and G.IsGroupHeadLine = 1
	WHERE D.Coll_Status IN ( SELECT val FROM [dbo].[strSplit](@Status,',')) 
		  AND (C.username = @Code OR @Code  = '')
		  AND (C.currency <> 20 OR @ExcludeTest = 0)
		  AND NOT EXISTS (SELECT 1 FROM custAccount m WITH (NOLOCK) WHERE m.GroupID <> 0 AND m.IsGroupHeadLine = 0 AND m.CustID = D.CustID)
		  AND NOT EXISTS (SELECT 1 FROM Dep_CustSuper s WITH (NOLOCK) WHERE s.CustID = c.CustID )  ---- exclude Licensee
			 
	/* 2. Member of group headline and direct account table*/	
	CREATE TABLE #GroupDetailAll
	(
		CustId			INT,
		GroupID			INT,
		IsGroup			BIT,
		Username		VARCHAR(30),
		RoleId			TINYINT,
		IsOLD			BIT DEFAULT (0),
		IsCal			BIT DEFAULT (0) 
		
	)	

	CREATE TABLE #GroupDetail
	(
		CustId			INT,
		GroupID			INT,
		IsGroup			BIT,
		Username		VARCHAR(30),
		RoleId			TINYINT,
		IsOLD			BIT DEFAULT (0),
		IsCal			BIT DEFAULT (0) 
		
	)	
	
	INSERT INTO #GroupDetailAll (CustId, GroupID, IsGroup, Username, RoleId, IsOLD)
	SELECT	M.CustID, M.GroupID, 1 as IsGroup, C.Username, C.roleid, CASE WHEN c.Username LIKE '%OLD' THEN 1 ELSE 0 END
	FROM	#GroupHeadLineAll H
		INNER JOIN dbo.custAccount M WITH (NOLOCK) ON M.GroupID = H.GroupID
		INNER JOIN dbo.Customer C WITH (NOLOCK) ON M.CustID = C.CustID
	WHERE   H.IsGroupHeadLine = 1  --- insert member of Group  
			AND M.GroupID <> 0
			AND (C.currency <> 20 OR @ExcludeTest = 0)

	INSERT INTO #GroupDetailAll (CustId, GroupID, IsGroup, Username, RoleId, IsOLD)
	SELECT	H.CustId, H.GroupID, 0 as IsGroup, C.Username, C.roleid, CASE WHEN c.Username LIKE '%OLD' THEN 1 ELSE 0 END
	FROM	#GroupHeadLineAll H
		INNER JOIN dbo.Customer C WITH (NOLOCK) ON H.CustID = C.CustID
	WHERE   H.IsGroupHeadLine = 0  ---insert direct Account 
			AND (C.currency <> 20 OR @ExcludeTest = 0)	
	
		------Paging
	
	DECLARE @GroupID AS TABLE (GroupID INT) 

	SELECT @totalItems = COUNT(*)
	FROM  (
			SELECT ROW_NUMBER() OVER (ORDER BY h.GroupID) rn, h.GroupID
			FROM  #GroupHeadLineAll h					
			WHERE EXISTS (SELECT 1 FROM #GroupDetailAll d WHERE d.GroupID = h.GroupID AND (d.IsOLD = @Type OR @Type = 2 ))
			) t 

	 
	INSERT INTO @GroupID (GroupId) 
	SELECT t.GroupID
	FROM (
		SELECT ROW_NUMBER() OVER (ORDER BY h.GroupID) rn, h.GroupID
		FROM  #GroupHeadLineAll h					
		WHERE EXISTS (SELECT 1 FROM #GroupDetailAll d WHERE d.GroupID = h.GroupID AND (d.IsOLD = @Type OR @Type = 2 ))
		) t
	WHERE	(t.rn BETWEEN @RowStart and @RowEnd)
			OR (@pageSize = -1) ---- all page

	 
	INSERT INTO #GroupHeadLine (CustId, Username, Coll_Status, IsGroupHeadLine, GroupID)
	SELECT CustId, Username, Coll_Status, IsGroupHeadLine, GroupID
	FROM  #GroupHeadLineAll t
	WHERE EXISTS (SELECT 1 FROM @GroupID g WHERE g.GroupID = t.GroupID)

	 
	INSERT INTO #GroupDetail (CustId, GroupID, IsGroup, Username, RoleId, IsOLD)  
	SELECT CustId, GroupID, IsGroup, Username, RoleId, IsOLD
	FROM  #GroupDetailAll t
	WHERE EXISTS (SELECT 1 FROM @GroupID g WHERE g.GroupID = t.GroupID)

   
 
		   
	/* 3.Get Balance */	
	DECLARE @strCustIds VARCHAR(MAX) = '', @RowCount INT
	
	CREATE TABLE #CustBalance (CustId INT, WinlostDate SMALLDATETIME, Balance MONEY)
	
	---- Begin Bettrans range
	DECLARE @CustTmp AS TABLE (CustId INT)	
	
	DECLARE @i BIGINT = 1000000  ---- large number means no loop at this time	
	
	------ LOOP
	----* Super level *----
	SELECT @RowCount = 1 

	WHILE @RowCount <> 0 
	BEGIN
		DELETE @CustTmp 
		SELECT @RowCount = 0
			 		
		UPDATE TOP (@i) c
		SET		IsCal = 1
		OUTPUT  inserted.CustId INTO @CustTmp
		FROM	#GroupDetail c
		WHERE	IsCal = 0 
				AND RoleID = 4
 
		SELECT @RowCount = @@ROWCOUNT
		
		IF @RowCount <> 0 
		BEGIN 
			SET @strCustIds = ''
			SET @strCustIds = ( SELECT CustId  AS '@CustId' 
								FROM @CustTmp			 
								FOR XML PATH('r'), ROOT( 'ROOT' ))
								
			IF @HasBT_BK = 1 
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC bodb_report.dbo.Acc_Rpt_CreditCollection_GetBalance_BK
						@FromDate = @FromDateBT_BK,
						@ToDate = @ToDateBT_BK,
						@CustIDList =@strCustIds,
						@LimitMonth = @LimitMonth
			END

			IF @HasBT_14 = 1 AND (@HasBT_BK <> 1 OR @HasBT <> 1)
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC bodb_report.dbo.Acc_Rpt_CreditCollection_GetBalance_14 
						@FromDate = @FromDateBT_14,
						@ToDate = @ToDateBT_14,						
						@CustIDList =@strCustIds,
						@LimitMonth = @LimitMonth,
						@BalanceUpDay = @BalanceUpDay
						 
			END
						 		 
			IF @HasBT = 1 
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC dbo.Acc_Rpt_CreditCollection_GetBalance_Super 
						@FromDate = @FromDateBT,
						@ToDate = @ToDateBT,
						@CustIDList =@strCustIds 
			END
		END
	 END  


	----* Master level *----
	SELECT @RowCount = 1 

	WHILE @RowCount <> 0 
	BEGIN
		DELETE @CustTmp 
		SELECT @RowCount = 0
			 		
		UPDATE TOP (@i) c
		SET		IsCal = 1
		OUTPUT  inserted.CustId INTO @CustTmp
		FROM	#GroupDetail c
		WHERE	IsCal = 0 
				AND RoleID = 3

		SELECT @RowCount = @@ROWCOUNT

		IF @RowCount <> 0 
		BEGIN 

			SET @strCustIds = ''
			SET @strCustIds = ( SELECT CustId  AS '@CustId' 
								FROM @CustTmp			 
								FOR XML PATH('r'), ROOT( 'ROOT' ))

			IF @HasBT_BK = 1 
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC bodb_report.dbo.Acc_Rpt_CreditCollection_GetBalance_BK
						@FromDate = @FromDateBT_BK,
						@ToDate = @ToDateBT_BK,
						@CustIDList =@strCustIds 
			END

			IF @HasBT_14 = 1 AND (@HasBT_BK <> 1 OR @HasBT <> 1)
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC bodb_report.dbo.Acc_Rpt_CreditCollection_GetBalance_14 
						@FromDate = @FromDateBT_14,
						@ToDate = @ToDateBT_14,						
						@CustIDList =@strCustIds,
						@LimitMonth = @LimitMonth,
						@BalanceUpDay = @BalanceUpDay
			END

			IF @HasBT = 1 
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC dbo.Acc_Rpt_CreditCollection_GetBalance_Master 
						@FromDate = @FromDateBT,
						@ToDate = @ToDateBT,
						@CustIDList =@strCustIds 
			END
		END
	 END 


	----* Agent level *----
	SELECT @RowCount = 1 

	WHILE @RowCount <> 0 
	BEGIN
		DELETE @CustTmp 
		SELECT @RowCount = 0
			 		
		UPDATE TOP (@i) c
		SET		IsCal = 1
		OUTPUT  inserted.CustId INTO @CustTmp
		FROM	#GroupDetail c
		WHERE	IsCal = 0 
				AND RoleID = 2

		SELECT @RowCount = @@ROWCOUNT

		IF @RowCount <> 0 
		BEGIN 

			SET @strCustIds = ''
			SET @strCustIds = ( SELECT CustId  AS '@CustId' 
								FROM @CustTmp			 
								FOR XML PATH('r'), ROOT( 'ROOT' ))

			IF @HasBT_BK = 1 
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC bodb_report.dbo.Acc_Rpt_CreditCollection_GetBalance_BK
						@FromDate = @FromDateBT_BK,
						@ToDate = @ToDateBT_BK,
						@CustIDList =@strCustIds 
			END

			IF @HasBT_14 = 1 AND (@HasBT_BK <> 1 OR @HasBT <> 1)
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC bodb_report.dbo.Acc_Rpt_CreditCollection_GetBalance_14 
						@FromDate = @FromDateBT_14,
						@ToDate = @ToDateBT_14,						
						@CustIDList =@strCustIds,
						@LimitMonth = @LimitMonth,
						@BalanceUpDay = @BalanceUpDay 
			END

			IF @HasBT = 1 
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC dbo.Acc_Rpt_CreditCollection_GetBalance_Agent
						@FromDate = @FromDateBT,
						@ToDate = @ToDateBT,
						@CustIDList =@strCustIds 
			END
		END
	 END 

	----* Member level *----
	 
	SELECT @RowCount = 1 

	WHILE @RowCount <> 0 
	BEGIN
		DELETE @CustTmp 
		SELECT @RowCount = 0
			 		
		UPDATE TOP (@i) c
		SET		IsCal = 1
		OUTPUT  inserted.CustId INTO @CustTmp
		FROM	#GroupDetail c
		WHERE	IsCal = 0 
				AND RoleID = 1

		SELECT @RowCount = @@ROWCOUNT

		 
		IF @RowCount <> 0 
		BEGIN 

			SET @strCustIds = ''
			SET @strCustIds = ( SELECT CustId  AS '@CustId' 
								FROM @CustTmp			 
								FOR XML PATH('r'), ROOT( 'ROOT' ))								 

			IF @HasBT_BK = 1 
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC bodb_report.dbo.Acc_Rpt_CreditCollection_GetBalance_BK
						@FromDate = @FromDateBT_BK,
						@ToDate = @ToDateBT_BK,
						@CustIDList =@strCustIds 
			END

			IF @HasBT_14 = 1 AND (@HasBT_BK <> 1 OR @HasBT <> 1)
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC bodb_report.dbo.Acc_Rpt_CreditCollection_GetBalance_14 
						@FromDate = @FromDateBT_14,
						@ToDate = @ToDateBT_14,						
						@CustIDList =@strCustIds,
						@LimitMonth = @LimitMonth,
						@BalanceUpDay = @BalanceUpDay
						 
			END				 

			IF @HasBT = 1 
			BEGIN  
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC dbo.Acc_Rpt_CreditCollection_GetBalance_Member
						@FromDate = @FromDateBT,
						@ToDate = @ToDateBT,
						@CustIDList =@strCustIds 
			END
		END
	 END 
	 ---- End Bettrans range
	 
	 ---- Begin BK and 14 range
	 
			SET @strCustIds = ''
			SET @strCustIds = ( SELECT CustId  AS '@CustId' 
								FROM  #GroupDetail		 
								FOR XML PATH('r'), ROOT( 'ROOT' ))
			
			IF @HasBT_BK = 1 
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC bodb_report.dbo.Acc_Rpt_CreditCollection_GetBalance_BK
						@FromDate = @FromDateBT_BK,
						@ToDate = @ToDateBT_BK,
						@CustIDList =@strCustIds 
			END

			IF @HasBT_14 = 1 AND (@HasBT_BK <> 1 OR @HasBT <> 1)
			BEGIN 
				INSERT INTO #CustBalance (CustId, WinlostDate, Balance)
				EXEC bodb_report.dbo.Acc_Rpt_CreditCollection_GetBalance_14 
						@FromDate = @FromDateBT_14,
						@ToDate = @ToDateBT_14,						
						@CustIDList =@strCustIds,
						@LimitMonth = @LimitMonth,
						@BalanceUpDay = @BalanceUpDay
						 
			END			
			 	
	 ---- End BK and 14 range
	 
	   
	---------------------------------------------------------------------------------------

	/* Breakdown */	 
	/* BreakDowns by week*/			
	CREATE TABLE #BreakDowns (StartDate DATETIME ,EndDate DATETIME)
	CREATE TABLE #Transfer (CustId INT, StartDate DATETIME, EndDate DATETIME, Amount MONEY)

	DECLARE @WeekDay INT
	DECLARE @StartDay DATETIME
	DECLARE @NextFriday DATETIME

	SET @WeekDay = DATEPART(WEEKDAY, @FromDate)	  

	SET @NextFriday = 
	CASE
		WHEN @WeekDay <=6 THEN DATEADD(DAY, 6 - @WeekDay, @FromDate)
		ELSE DATEADD(DAY, 6, @FromDate)
	END
	
	IF @NextFriday >= @ToDate
		SELECT @NextFriday = @ToDate

	INSERT INTO #BreakDowns(StartDate, EndDate) VALUES (@FromDate, @NextFriday) 
	
	WHILE @NextFriday < @ToDate 
	BEGIN 
		
		SELECT  @StartDay = DATEADD(DD, 1, @NextFriday)		 
		SELECT  @NextFriday = CASE WHEN DATEADD(DD, 7, @NextFriday) <  @ToDate  THEN DATEADD(DD, 7, @NextFriday) ELSE @ToDate  END
		INSERT INTO #BreakDowns(StartDate, EndDate) VALUES (@StartDay, @NextFriday) 
	END 

	/* Get Transfer_Coll from Breakdown */
	IF @HasBT = 1 OR @HasBT_14 = 1
	BEGIN 
		INSERT INTO #Transfer (CustId, StartDate, EndDate, Amount)	 
		SELECT	t.CustId, b.StartDate, b.EndDate, SUM((t.Credit - t.Debit) * t.ActualRate) As Amount
		FROM	dbo.Transfer_Coll t WITH (NOLOCK)  
			INNER JOIN #BreakDowns b 
				ON t.WinlostDate BETWEEN b.StartDate AND b.EndDate	
		WHERE EXISTS (SELECT 1 FROM #GroupDetail d WHERE d.CustId = t.CustId) 
		GROUP BY t.CustId, b.StartDate, b.EndDate
	END 

	IF @HasBT_BK = 1 
	BEGIN 
		INSERT INTO #Transfer (CustId, StartDate, EndDate, Amount)	 
		SELECT	t.CustId, b.StartDate, b.EndDate, SUM((t.Credit - t.Debit)* t.ActualRate) As Amount
		FROM	bodb_archive.dbo.Transfer_Coll_BK t WITH (NOLOCK)  
			INNER JOIN #BreakDowns b 
				ON t.WinlostDate BETWEEN b.StartDate AND b.EndDate	
		WHERE EXISTS (SELECT 1 FROM #GroupDetail d WHERE d.CustId = t.CustId) 
		GROUP BY t.CustId, b.StartDate, b.EndDate 
	END  
	 


	----------------Get Info 
	
	Select * from #BreakDowns 

	----- Main 
	SELECT H.CustID, H.GroupId, H.Username, H.Coll_Status, H.IsGroupHeadLine
	FROM  #GroupHeadLine H 
	ORDER BY GroupId 
	 

	---- Detail
	SELECT  D.GroupId, CASE WHEN IsOLD <> 1 AND IsGroup = 1 THEN 'Other Codes' ELSE D.Username END AS Username,   
			SUM (B.Balance) * -1 as Balance, B.WinlostDate
	FROM  #GroupDetail D
	LEFT JOIN #CustBalance B
		ON B.CustId = D.CustId AND B.WinlostDate IN (@FromDate, @ToDate + 1)
	GROUP BY  D.GroupId, CASE WHEN IsOLD <> 1 AND IsGroup = 1 THEN 'Other Codes' ELSE D.Username END, B.WinlostDate , IsOLD
	ORDER BY  GroupId, IsOLD DESC, WinlostDate

	 

	--- Collection Breakdown
	SELECT	D.GroupId, CASE WHEN IsOLD <> 1 AND IsGroup = 1 THEN 'Other Codes' ELSE D.Username END AS Username,  
			MIN(T.StartDate) AS StartDate , MIN(T.EndDate) AS EndDate , SUM (T.Amount) * -1 AS Amount
	FROM	#Transfer T
	INNER JOIN   #GroupDetail D
		ON D.CustID = T.CustID
	GROUP BY D.GroupId, CASE WHEN IsOLD <> 1 AND IsGroup = 1 THEN 'Other Codes' ELSE D.Username END , IsOLD
	ORDER BY  D.GroupId, IsOLD DESC 
	

	DROP TABLE #GroupHeadLineAll 
	DROP TABLE #GroupDetailAll
	DROP TABLE #GroupHeadLine 
	DROP TABLE #GroupDetail
	DROP TABLE #CustBalance 
	DROP TABLE #BreakDowns
	DROP TABLE #Transfer
	
	END 
	GO
