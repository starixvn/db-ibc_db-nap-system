/*<info serverAlias="DBRPT-bodb_report" executers="bodbAdminNet" isFunction="0" isNested="1"></info>*/
Use bodb_report
GO 

ALTER PROCEDURE [dbo].[Acc_Rpt_CreditCollection_GetBalance_Active]
	@FromDate	DATE,
	@ToDate		DATE,
	@CustIDList	VARCHAR(MAX),	
	@MoveBetsDay DATE,
	@BalanceUpDay DATE
AS

/*  Created:  20190521@Sophia
	DB:		DBRPT-bodb_report
	Task :  Get Total Balance from rptTotalBalance_Active
	
	Param's Explanation:  
	  + @CustIDList: xml structure
			<root>
				<r CustId="944306"/>
				<r CustId="944345"/>
				<r CustId="944355"/>
				<r CustId="944426"/> 
			</root>
						 

	Revisions:  
		- 20190521@Sophia: initial SP [Redmine: 109293]

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
		 CustId			INT
		,winlostdate		SMALLDATETIME	
		,OpeningTotalBalance MONEY	NULL		
	) 
 	 
	BEGIN 		
 
 		INSERT INTO #rptStatementTable (CustId, winlostdate, OpeningTotalBalance)	
		SELECT CustID, @ToDate AS winlostdate, OpeningTotalBalance
		FROM (
				SELECT t.CustID, MAX(r.winlostdate) AS winlostdate, r.OpeningTotalBalance
				FROM   #CustIds t 
				LEFT JOIN dbo.rptTotalBalance_Active r WITH (NOLOCK)	
					ON t.CustID = r.CustID 
				WHERE  r.Winlostdate <= @Todate
				GROUP BY t.CustID, r.OpeningTotalBalance
				) T			   
			   
		INSERT INTO #rptStatementTable (CustId, winlostdate, OpeningTotalBalance)	
		SELECT CustID, @FromDate AS winlostdate, OpeningTotalBalance
		FROM (
				SELECT t.CustID, MAX(r.winlostdate) AS winlostdate, r.OpeningTotalBalance
				FROM   #CustIds t 
				LEFT JOIN dbo.rptTotalBalance_Active r WITH (NOLOCK)	
					ON t.CustID = r.CustID 
				WHERE  r.Winlostdate <= @FromDate
				GROUP BY t.CustID, r.OpeningTotalBalance
				) F			
	END

 
	----======== Get data No Balance on @FromDate and @ToDate ======-------------
	DECLARE @MBSaturday DATE, @BUSaturday DATE, @i TINYINT
	
	SELECT @i = DATEPART (DW,@MoveBetsDay) 
	SELECT @MBSaturday = DATEADD ( DD, -@i, @MoveBetsDay)
	
	SELECT @i = DATEPART (DW,@BalanceUpDay) 
	SELECT @BUSaturday = DATEADD ( DD, -@i, @BalanceUpDay)
	
	------* rptStatement table * ----------
	---- IF no record of BL of FromDate, then get the nearest BL on rptStatement
	IF EXISTS ( SELECT	TOP 1 1 
				FROM	#rptStatementTable 
				WHERE 	OpeningTotalBalance IS NULL
						AND winlostdate = @FromDate)
	BEGIN 	
		
		INSERT INTO #rptStatementTable (CustId, winlostdate, OpeningTotalBalance)	
		SELECT f.CustID, @FromDate AS winlostdate, f.OpeningTotalBalance
		FROM (
			SELECT	t.CustId, MAX(r.Winlostdate), r.OpeningTotalBalance
			FROM 	
				(	SELECT	CustId, Winlostdate
					FROM	#rptStatementTable 
					WHERE 	OpeningTotalBalance IS NULL
							AND winlostdate = @FromDate
				) t
			LEFT JOIN dbo.rptStatement r WITH (NOLOCK) 
					ON t.CustID = r.CustID
			WHERE  r.Winlostdate >= @MBSaturday
			GROUP BY t.CustId, r.OpeningTotalBalance
			) f
		
		
		;WITH tmpDel AS (	SELECT CustID, Count (1) as Cnt
								FROM #rptStatementTable
								WHERE winlostdate = @FromDate
								GROUP BY CustID
								HAVING Count (1) > 1
										)		
		---- Delete BL of @Fromdate is null
		DELETE 	r
		FROM 	#rptStatementTable r			 
		WHERE 	r.OpeningTotalBalance IS NULL
				AND r.winlostdate = @FromDate
				AND EXISTS (SELECT 1 FROM tmpDel t WHERE t.CustID = r.CustID)

	END
	 
	
	------* End rptStatement table * ----------	
	

	------* rptStatement_old table * ----------
	---- IF no record of BL of FromDate, then get the nearest BL on rptStatement_old
			 
	IF EXISTS (		SELECT	TOP 1 1
					FROM	#rptStatementTable 
					WHERE 	OpeningTotalBalance IS NULL
							AND winlostdate = @FromDate)
	BEGIN 			
		INSERT INTO #rptStatementTable (CustId, winlostdate, OpeningTotalBalance)	
		SELECT CustID, @FromDate AS winlostdate, OpeningTotalBalance
		FROM (
			SELECT	t.CustId, MAX(r.Winlostdate), r.OpeningTotalBalance
			FROM 	(
						SELECT	CustId, Winlostdate
						FROM	#rptStatementTable 
						WHERE 	OpeningTotalBalance IS NULL
								AND winlostdate = @FromDate
					) t
			LEFT JOIN dbo.rptStatement_Old r WITH (NOLOCK) 
					ON t.CustID = r.CustID
			WHERE  r.Winlostdate >= @BUSaturday
			GROUP BY t.CustId, r.OpeningTotalBalance
			) F
		
		
		;WITH tmpDel AS (		SELECT CustID, Count (1) as Cnt
								FROM #rptStatementTable
								WHERE winlostdate = @FromDate
								GROUP BY CustID
								HAVING Count (1) > 1
										)										 		
		---- Delete BL of @Fromdate is null
		DELETE 	r
		FROM 	#rptStatementTable r			 
		WHERE 	r.OpeningTotalBalance IS NULL
				AND r.winlostdate = @FromDate
				AND EXISTS (SELECT 1 FROM tmpDel t WHERE t.CustID = r.CustID)	
								
	END 
	
	------* End rptStatement_old table * ----------	
	
		
	--- Update BL of @Todate = @FromDate 
	UPDATE 	t
	SET 	t.OpeningTotalBalance = f.OpeningTotalBalance
	FROM 	#rptStatementTable t 
		INNER JOIN #rptStatementTable f
			ON t.CustID = f.custid 				
			AND f.OpeningTotalBalance IS NOT NULL
			AND t.OpeningTotalBalance IS NULL
			AND f.winlostdate = @FromDate
			AND t.winlostdate = @Todate 

	
	----Show data
	SELECT 	r.CustId, r.winlostdate, (r.OpeningTotalBalance * e.ActualRate) AS OpeningTotalBalance 
	FROM 	#rptStatementTable r
	INNER JOIN bodb02.dbo.CustInfo c WITH (NOLOCK) 
			ON c.CustID = r.CustID
	INNER JOIN bodb02.dbo.ExchangeDailyOanda e WITH (NOLOCK) 
			ON e.ExchangeId = c.currency AND e.ExchangeDate = r.WinlostDate
	

	DROP TABLE #rptStatementTable
	DROP TABLE #CustIds 

END

GO