/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Acc_Rpt_CreditCollection_GetBalance_Agent]
	@FromDate	SMALLDATETIME,
	@ToDate		SMALLDATETIME,
	@CustIDList	VARCHAR(MAX)
AS
/*  Created: Sophia  
	Date:	20181206
	DB:		DBACC.bodb02 
	Task :  Get Balance for List Customer - Level Agent - Bettrans Range
	Prefer SP: Acc_StatementSel 
	

	Param's Explanation:  
	  + @CustIDList: xml structure
			<root>
				<r CustId="944306"/>
				<r CustId="944345"/>
				<r CustId="944355"/>
				<r CustId="944426"/> 
			</root>
						 

	Revisions:  
	- 20181206@Sophia: initial SP

*/  
 
BEGIN
	SET NOCOUNT ON

	---#1: Begin: Get CustID List
	CREATE TABLE #CustIds (CustId INT, IsCal BIT DEFAULT (0))
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @CustIdList

		INSERT INTO #CustIds (CustId)
		SELECT CustId 
		FROM OPENXML(@DocHandler, '/ROOT/r', 1) WITH (CustId INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100, ErrMsg = N'Paramter invalid.'
		RETURN
	END CATCH
	---#1: End: Get CustID List
	 

	---#2: Begin: Get Sport bettype Matrix 
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

	CREATE	TABLE #Sportbettype (Bettype INT PRIMARY KEY, RefTable TINYINT)
	INSERT	INTO #Sportbettype (Bettype, RefTable)
	SELECT	DISTINCT Bettype, RefTable 
	FROM	dbo.f_SportbettypeMatrix_Sel(0, 0, 0, 2, '', '', @isTest)
	WHERE	RefTable <> 0  -- get bettype in translog, bettransRnG, bettransLC
		 -- RefTable: 0-bettrans, 1-bettransRnG, 2-bettransLC, 3-translog

	---#2: BeginEnd Get Sport bettype Matrix 

	
	CREATE TABLE #Data (
		 OwnerID			INT
		,winlostdate		SMALLDATETIME
		,Bettype			SMALLINT
		,StatusID			SMALLINT
		,IsOwner			BIT     DEFAULT 0		
		,Outstanding		MONEY	NULL
		,Turnover			MONEY	NULL
		,Winlost			MONEY	NULL
		,Comm				MONEY	NULL
		,BetCount			INT		DEFAULT 0
		,OwnerWinloss		MONEY	NULL
		
	)

	CREATE TABLE #rptStatementTable(
		 OwnerID			INT
		,winlostdate		SMALLDATETIME	
		,OpeningBalance		MONEY	NULL		
		,Winlost			MONEY	NULL
		,Comm				MONEY	NULL	
		,Balance			MONEY		
		,IsOpeningBalance	BIT		DEFAULT 0
	)
	
	/*
	DELETE #CustIds 
	WHERE CustID IN (7214059,7213826,7213962)   --- Special acc    (ROLEID = 1 )
	*/
	
	
	---#3: Begin: Get Data from Bettrans table. Because of the suitable index is IX_recommend, then we will use index on recommend level. 
	 
	SELECT @ToDate = DATEADD (dd, 1, @ToDate)  --- plus one day to calculate the openning BL of the day after (@ToDate + 1)  = the closing BL of the day before (@ToDate)
 
	DECLARE @i BIGINT = 10000000  -- use optimize for
	DECLARE @total MONEY = 0 -- to calculate OpeningBalance
	
	DECLARE @tbl TABLE(winlostdate SMALLDATETIME)	
	
	;WITH CTE_WinlostDate (winlostdate) AS
	(		
		SELECT @fromdate as winlostdate
		UNION ALL
		SELECT DATEADD(DAY, 1, winlostdate) as winlostdate
		FROM CTE_WinlostDate
		WHERE winlostdate < @Todate		
	)
	INSERT INTO @tbl (Winlostdate)
	SELECT Winlostdate FROM CTE_WinlostDate
	OPTION (MAXRECURSION 0)
	 
		
	DECLARE @yesterday SMALLDATETIME 
	SELECT  @yesterday =  CONVERT(DATE, DATEADD(DAY, -1, GETDATE()))


	--- IF @roleid = 2
	BEGIN 
		-- I.2.1. Bettrans (downline and itself): Exclude ticket running, waiting, Void, reject
		INSERT INTO #Data (OwnerID, winlostdate, bettype, StatusID, IsOwner, Turnover, OwnerWinloss, Winlost, Comm, BetCount)
		SELECT
			r.CustId, winlostdate, bettype, StatusID, IsOwner
			,SUM( ABS(stake) ) AS Turnover
			,SUM(winlost - actual_stake) AS OwnerWinloss
			,SUM(awinlost) AS winlost
			,SUM(comm - playercomm) AS comm
			,COUNT(1) AS betcount
		FROM #CustIds r
		CROSS APPLY (
					SELECT TOP (@i) winlostdate, StatusID, bettype, stake * actualrate as stake, winlost * actualrate as winlost, actual_stake * actualrate as actual_stake, awinlost * actualrate as awinlost, comm * actualrate as comm, playercomm * actualrate as playercomm, 
								 CASE WHEN recommend = CustID THEN 1 ELSE 0 END as IsOwner
					FROM dbo.bettrans bt WITH (NOLOCK)		-- use index = IX_recommend					
					WHERE r.CustID = bt.recommend
						AND winlostdate <= @todate			
						AND StatusID NOT IN (0,1)
					) b
		GROUP BY r.CustId, winlostdate, bettype, StatusID, IsOwner 
		OPTION (OPTIMIZE FOR (@i = 1), HASH GROUP)


		 
		-- I.2.2. BettransLC:  Exclude ticket running, waiting 
		INSERT INTO #Data (OwnerID, winlostdate, bettype, StatusID, IsOwner, Turnover, OwnerWinloss, Winlost, Comm, BetCount)
			SELECT
			r.CustId, winlostdate 
			,-1 as bettype  --- Get a general bettype for BettransLC/BettransRNG
			,StatusID
			,0 as IsOwner
			,SUM(ABS(stake)) AS Turnover
			,0 AS OwnerWinloss
			,SUM(awinlost) AS winlost
			,SUM(comm - playercomm) AS comm
			,COUNT(1) AS betcount 
		FROM #CustIds r
		CROSS APPLY (
					SELECT TOP (@i) winlostdate, StatusID, stake * actualrate as stake , awinlost * actualrate as awinlost, comm * actualrate as comm, playercomm * actualrate as playercomm
					FROM dbo.bettransLC bt WITH (NOLOCK)		-- use index = IX_recommend					
					WHERE r.CustId = bt.recommend
						AND winlostdate <= @todate
						AND winlostdate >= @yesterday				
						AND StatusID NOT IN (0,1)
					) b
		GROUP BY r.CustId, winlostdate, StatusID
		OPTION (OPTIMIZE FOR (@i = 1))
		

		-- I.2.3. BettransRNG: Exclude ticket running, waiting 
		INSERT INTO #Data (OwnerID, winlostdate, Bettype, StatusID, IsOwner, Turnover, OwnerWinloss, Winlost, Comm, BetCount)	
		SELECT
			r.CustId, winlostdate 
			,-1 as bettype  --- Get a general bettype for BettransLC/BettransRNG
			,StatusID
			,0 as IsOwner
			,SUM(ABS(stake)) AS Turnover
			,0 AS OwnerWinloss
			,SUM(awinlost) AS winlost
			,SUM(comm - playercomm) AS comm
			,COUNT(1) AS betcount 
		FROM #CustIds r
		CROSS APPLY (
					SELECT TOP (@i) winlostdate, StatusID,  stake * actualrate as stake , awinlost * actualrate as awinlost, comm * actualrate as comm, playercomm * actualrate as playercomm
					FROM dbo.bettransRNG bt WITH (NOLOCK)		-- use index = IX_recommend					
					WHERE r.custId = bt.recommend
						AND winlostdate <= @todate
						AND winlostdate >= @yesterday				
						AND StatusID NOT IN (0,1)
					) b
		GROUP BY r.CustId, winlostdate, StatusID
		OPTION (OPTIMIZE FOR (@i = 1))

	END
	-- End Agent --


	CREATE CLUSTERED INDEX IX_Data ON #Data (OwnerID, Bettype, WinlostDate, StatusID)

	-- II. Calculate data
	-- II.1 Get Winloss  
	-- @roleid IN (1,2,3,4)
	BEGIN		
		; WITH CTE_Winloss (OwnerID, winlostdate, winlost, comm) AS
		(			
			SELECT
				OwnerID
				,winlostdate
				,SUM(winlost) AS winlost
				,SUM(comm) AS comm
			FROM #Data bt			
			WHERE   bt.winlostdate BETWEEN @fromdate AND @todate
				AND bt.statusID NOT IN (0,1) 
				AND bt.bettype <= 19999  
						
				AND (  
						bt.bettype = -1	  --- BettransRNG/LC table group		
						OR 
						(    --- bettrans table group
							bt.bettype <> -1 AND bt.statusID NOT IN (102,101)
							AND NOT EXISTS (SELECT 1 FROM #Sportbettype s WHERE s.Bettype = bt.bettype AND s.RefTable <> 3 AND bt.winlostdate >= @yesterday) -- exclude running tickets on bettransRnG/LC								
						)				
					)
			GROUP BY OwnerID, winlostdate			
			
			) 
		INSERT INTO #rptStatementTable (OwnerID, winlostdate, Winlost, Comm)
		SELECT OwnerID, winlostdate,
			SUM (Winlost) as Winlost,
			SUM (Comm) as Comm
		FROM CTE_Winloss
		GROUP BY OwnerID, winlostdate	
	END  
	
	-- III. Get Openning Balance ----	
	-- @roleid IN (1,2,3,4)
	BEGIN
		;WITH CTE_Balance (OwnerID, winlostdate, Balance) AS
		(			
			SELECT 
				OwnerID,
				CASE WHEN winlostdate < @fromdate THEN @fromdate ELSE DATEADD(DAY, 1, winlostdate) END AS winlostdate,
				SUM(CASE WHEN IsOwner = 1 THEN OwnerWinloss ELSE winlost + comm END) AS OpeningBalance
			FROM #Data bt  				
			WHERE statusID NOT IN (0, 1)
				AND winlostdate < @todate
				AND ( 
						bt.Bettype = -1
						OR (bt.Bettype <> -1 
							AND NOT EXISTS ( SELECT 1 FROM #Sportbettype s WHERE s.Bettype = bt.bettype AND s.RefTable <> 3  AND bt.winlostdate >= @yesterday) -- exclude tickets on bettransRnG/LC today, yesterday
							)
					)				
			GROUP BY OwnerID, CASE WHEN winlostdate < @fromdate THEN @fromdate ELSE DATEADD(DAY, 1, winlostdate) END

		)
		INSERT INTO #rptStatementTable (OwnerID, winlostdate, Balance, IsOpeningBalance)
		SELECT
			cb.OwnerID,
			tmp.winlostdate,
			SUM(ISNULL(Balance, 0)),
			1
		FROM
			@tbl tmp
			INNER  JOIN CTE_Balance cb ON tmp.winlostdate = cb.winlostdate
		GROUP BY cb.OwnerID, tmp.winlostdate
		ORDER BY cb.OwnerID, winlostdate 	
		  
				
		/*Calculate Opening Balance*/
		DECLARE @OwnerID INT = 0		

		--SELECT TOP (1) @OwnerID =  CustId 
		--FROM #CustIds
		--WHERE IsCal = 0 

		UPDATE TOP (1) c
		SET		@OwnerID = CustId , IsCal = 1
		FROM	#CustIds c
		WHERE	IsCal = 0 

		WHILE  @OwnerID <> 0 	 
		BEGIN
			SELECT @total = 0

			UPDATE #rptStatementTable
			SET OpeningBalance = @total, @total = @total + Balance -- running total
			WHERE IsOpeningBalance = 1 
				  AND OwnerID = @OwnerID


 			SET @OwnerID = 0 

			UPDATE TOP (1) c
			SET		@OwnerID = CustId , IsCal = 1
			FROM	#CustIds c
			WHERE	IsCal = 0 
		END 			

		/*End Calculate Opening Balance*/
	END
	 
	 			 
	-- V. Show statement report
	DELETE #rptStatementTable
	WHERE Winlostdate < @FromDate
		OR IsOpeningBalance = 0			
	
	
	;WITH CTE_Balance (OwnerID, MaxDate, MinDate ) AS 
	(	SELECT	OwnerID, MAX(WinlostDate) MaxDate, MIN(WinlostDate) MinDate
		FROM	#rptStatementTable 
		GROUP BY OwnerID 
	)
	SELECT r.OwnerID  
		, @FromDate AS WinlostDate
		, CASE WHEN @FromDate = m.MinDate THEN SUM(ISNULL(r.OpeningBalance, 0)) ELSE 0 END AS OpeningBalance
	FROM #rptStatementTable r
		INNER JOIN CTE_Balance m 
			ON m.OwnerID = r.OwnerID AND r.WinlostDate = m.MinDate	 
	GROUP BY r.WinlostDate, r.OwnerID ,m.MinDate
	UNION ALL
	SELECT r.OwnerID  
		, @ToDate AS WinlostDate 
		,SUM(ISNULL(r.OpeningBalance, 0)) AS OpeningBalance
	FROM #rptStatementTable r
		INNER JOIN CTE_Balance m 
			ON m.OwnerID = r.OwnerID AND r.WinlostDate = m.MaxDate	 
	GROUP BY r.WinlostDate, r.OwnerID  



	DROP TABLE #rptStatementTable
	DROP TABLE #Sportbettype
	DROP TABLE #Data 
	 
END

GO 


 
