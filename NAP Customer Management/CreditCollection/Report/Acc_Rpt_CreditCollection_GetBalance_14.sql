/*<info serverAlias="DBRPT-bodb_report" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Acc_Rpt_CreditCollection_GetBalance_14]
	@FromDate	DATE,
	@ToDate		DATE,
	@CustIDList	VARCHAR(MAX),	
	@LimitMonth TINYINT = 1,
	@BalanceUpDay DATE
AS
/*  Created: Sophia  
	Date:	20181206
	DB:		DBRPT-bodb_report
	Task :  Get Balance for List Customer - Level Super - Bettrans14 Range [Redmine: 98621]
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
	  

	CREATE TABLE #rptStatementTable(
		 OwnerID			INT
		,winlostdate		SMALLDATETIME	
		,OpeningBalance		MONEY	NULL		
		,ClosingBalance		MONEY	NULL
	)
	
	/*
	DELETE #CustIds 
	WHERE CustID IN (7214059,7213826,7213962)   --- Special acc    (ROLEID = 1 )
	*/	
 	
	-- Super --		
	BEGIN
		CREATE TABLE #Tmp (CustID INT, Winlostdate DATE)	
		
		INSERT INTO #Tmp
		SELECT CustID, @FromDate
		FROM #CustIds
		UNION ALL
		SELECT CustID, @ToDate
		FROM #CustIds

		
		INSERT INTO #rptStatementTable (OwnerID, winlostdate, OpeningBalance, ClosingBalance)		
		SELECT r.CustID, r.winlostdate, r.OpeningBalance, r.ClosingBalance
		FROM dbo.rptStatement r WITH (NOLOCK)	
		CROSS APPLY (SELECT t.*
					 FROM #Tmp t
					 WHERE t.CustID = r.CustID AND r.Winlostdate = t.Winlostdate) c	
	END
	-- End Super --

	----======== Get data No Balance on @FromDate and @ToDate ======-------------
	DECLARE @FromDateNoBL AS TABLE (CustID INT)
	DECLARE @ToDateNoBL AS TABLE (CustID INT)

	DECLARE @LimitDate DATE 
	SELECT @LimitDate = DATEADD (Month, - @LimitMonth , @FromDate) 
	
	
	CREATE TABLE #TmpFrom (CustID INT, Winlostdate DATE)	
	CREATE TABLE #TmpTo (CustID INT, Winlostdate DATE)	
	------* rptStatement table * ----------

	INSERT INTO @FromDateNoBL (CustID)
	SELECT	c.CustId 
	FROM	#CustIds c
	WHERE	NOT EXISTS (SELECT 1 FROM #rptStatementTable s WHERE s.OwnerID = c.CustID AND s.WinlostDate = @FromDate) 
 	
	INSERT INTO @ToDateNoBL (CustID)
	SELECT	c.CustId 
	FROM	#CustIds c
	WHERE	NOT EXISTS (SELECT 1 FROM #rptStatementTable s WHERE s.OwnerID = c.CustID AND s.WinlostDate = @ToDate) 
	 

	---- IF @FromDate no record of BL then get the nearest BL of FromDate 
	IF EXISTS  (SELECT 1 FROM @FromDateNoBL)
	BEGIN 
						
		;WITH CTE_Winlostdate (winlostdate, CustId) AS
		(
			SELECT	@BalanceUpDay AS winlostdate, CustId
			FROM	@FromDateNoBL
			UNION ALL
			SELECT	DATEADD(DAY, 1, winlostdate), CustId
			FROM	CTE_Winlostdate
			WHERE	winlostdate <= @FromDate
					 
		)	
		INSERT INTO #TmpFrom (winlostdate, CustId)
		SELECT winlostdate, CustId
		FROM CTE_Winlostdate
		OPTION ( MAXRECURSION 0)
		
			
		INSERT INTO #rptStatementTable (OwnerID, winlostdate, OpeningBalance, ClosingBalance)	
		SELECT CustID, @FromDate, OpeningBalance, ClosingBalance 
		FROM  ( 
				SELECT r.CustID, MAX(r.winlostdate) AS winlostdate, r.ClosingBalance as OpeningBalance , r.ClosingBalance as ClosingBalance
				FROM dbo.rptStatement r WITH (NOLOCK)		
					CROSS APPLY (	SELECT	t.* 
									FROM	#TmpFrom t 
									WHERE	t.CustID = r.CustID AND t.Winlostdate = r.Winlostdate 
								) c		
				GROUP BY r.CustID , r.ClosingBalance 		
		       ) a
		OPTION (MAXDOP 3)				

	 
	END 
 
 	---- IF @FromDate no record of BL then get the nearest BL of @ToDate 

	IF EXISTS (SELECT 1 FROM @ToDateNoBL)
	BEGIN 
	
		;WITH CTE_Winlostdate (winlostdate, CustId) AS
		(
			SELECT	@BalanceUpDay AS winlostdate, CustId
			FROM	@ToDateNoBL
			UNION ALL
			SELECT	DATEADD(DAY, 1, winlostdate), CustId
			FROM	CTE_Winlostdate
			WHERE	winlostdate <= @ToDate						 
		)	
		INSERT INTO #TmpTo (winlostdate, CustId)
		SELECT winlostdate, CustId
		FROM CTE_Winlostdate
		OPTION (MAXRECURSION 0)
		
			
		INSERT INTO #rptStatementTable (OwnerID, winlostdate, OpeningBalance, ClosingBalance)		
		SELECT CustID, @ToDate, OpeningBalance, ClosingBalance 
		FROM  ( 
				SELECT r.CustID, MAX(r.winlostdate) AS winlostdate, r.ClosingBalance as OpeningBalance, r.ClosingBalance as ClosingBalance
				FROM dbo.rptStatement r WITH (NOLOCK)		
					CROSS APPLY ( 
									SELECT * 
									FROM #TmpTo t 
									WHERE t.CustID = r.CustID AND t.Winlostdate = r.Winlostdate 
								) c
				WHERE
					r.winlostdate < @ToDate	
				GROUP BY r.CustID, r.ClosingBalance 
		) a
		OPTION (MAXDOP 3)	

	END 

	 
	------* rptStatement_old table * ----------	

	DELETE @FromDateNoBL
	DELETE @ToDateNoBL

	INSERT INTO @FromDateNoBL (CustID)
	SELECT	c.CustId 
	FROM	#CustIds c
	WHERE	NOT EXISTS (SELECT 1 FROM #rptStatementTable s WHERE s.OwnerID = c.CustID AND s.WinlostDate = @FromDate) 
 	
	INSERT INTO @ToDateNoBL (CustID)
	SELECT	c.CustId 
	FROM	#CustIds c
	WHERE	NOT EXISTS (SELECT 1 FROM #rptStatementTable s WHERE s.OwnerID = c.CustID AND s.WinlostDate = @ToDate) 
	 

	---- IF @FromDate no record of BL then get the nearest BL of FromDate 
	IF EXISTS (SELECT 1 FROM @FromDateNoBL)
	BEGIN 
		INSERT INTO #rptStatementTable (OwnerID, winlostdate, OpeningBalance, ClosingBalance)	
		SELECT CustID, @FromDate, OpeningBalance, ClosingBalance 
		FROM  ( 
				SELECT r.CustID, MAX(r.winlostdate) AS winlostdate, r.ClosingBalance as OpeningBalance, r.ClosingBalance as ClosingBalance
				FROM dbo.rptStatement_Old r WITH (NOLOCK)			
				WHERE 
					EXISTS (SELECT 1 FROM @FromDateNoBL c WHERE c.CustID = r.custid)
					AND r.winlostdate < @FromDate
					AND r.winlostdate >= @LimitDate
				GROUP BY r.CustID , r.ClosingBalance  
			) a
		OPTION (MAXDOP 3)
	END 
 
 	---- IF @FromDate no record of BL then get the nearest BL of FromDate 
	IF EXISTS  (SELECT 1 FROM @ToDateNoBL)
	BEGIN 
		INSERT INTO #rptStatementTable (OwnerID, winlostdate, OpeningBalance, ClosingBalance)	
		SELECT CustID, @ToDate, OpeningBalance, ClosingBalance 
		FROM  ( 		
			SELECT r.CustID, MAX(r.winlostdate) AS winlostdate, r.ClosingBalance as OpeningBalance , r.ClosingBalance as ClosingBalance
			FROM dbo.rptStatement_Old r WITH (NOLOCK)			
			WHERE 
				EXISTS (SELECT 1 FROM @ToDateNoBL c WHERE c.CustID = r.custid)
				AND r.winlostdate < @ToDate
				AND r.winlostdate >= @LimitDate		
			GROUP BY r.CustID ,r.ClosingBalance 
			) a
		OPTION (MAXDOP 3)
	END 

	 

	----Show data
	;WITH CTE_Balance (OwnerID, MaxDate, MinDate, currency ) AS 
	(	SELECT	OwnerID, MAX(WinlostDate) MaxDate, MIN(WinlostDate) MinDate, currency
		FROM	#rptStatementTable o
		INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) 
				ON c.CustID = o.OwnerID
		GROUP BY OwnerID ,currency
	)
	SELECT r.OwnerID  
		, @FromDate AS WinlostDate
		,SUM(ISNULL(r.OpeningBalance, 0) * e.ActualRate) AS OpeningBalance
	FROM #rptStatementTable r
		INNER JOIN CTE_Balance m 
			ON m.OwnerID = r.OwnerID AND r.WinlostDate = m.MinDate	 
		INNER JOIN bodb02.dbo.ExchangeDailyOanda e WITH (NOLOCK) 
			ON e.ExchangeId = m.currency and e.ExchangeDate = r.WinlostDate
	GROUP BY r.WinlostDate, r.OwnerID  

	UNION ALL
 
	SELECT r.OwnerID  
		,DATEADD(DD,1,@ToDate) AS WinlostDate 
		,SUM (ISNULL(r.ClosingBalance, 0) * e.ActualRate) AS OpeningBalance   ---- OpeningBalance of @ToDate + 1 means closing BL of @ToDate 
	FROM #rptStatementTable r
		INNER JOIN CTE_Balance m 
			ON m.OwnerID = r.OwnerID AND r.WinlostDate = m.MaxDate	 	
		INNER JOIN bodb02.dbo.ExchangeDailyOanda e WITH (NOLOCK) 
			ON e.ExchangeId = m.currency and e.ExchangeDate = r.WinlostDate
	GROUP BY r.WinlostDate, r.OwnerID  
	
		 	

	DROP TABLE #rptStatementTable
	DROP TABLE #CustIds

END

GO