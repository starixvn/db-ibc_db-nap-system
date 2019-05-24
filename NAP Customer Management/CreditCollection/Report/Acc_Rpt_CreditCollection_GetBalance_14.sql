/*<info serverAlias="DBRPT-bodb_report" executers="bodbAdminNet" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Acc_Rpt_CreditCollection_GetBalance_14]
	@FromDate	DATE,
	@ToDate		DATE,
	@CustIDList	VARCHAR(MAX),	
	@MoveBetsDay DATE,
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
	- 20190520@Sophia: Change report get total Balance [redmine: #109293]

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

	DECLARE @MBSaturday DATE, @BUSaturday DATE, @i TINYINT

	SELECT @i = DATEPART (DW,@MoveBetsDay) 	
	SELECT @MBSaturday = DATEADD ( DD, -@i, @MoveBetsDay)	
	
	SELECT @i = DATEPART (DW,@BalanceUpDay) 
	SELECT @BUSaturday = DATEADD ( DD, -@i, @BalanceUpDay)		
	-----------------------------------------------------
	
	CREATE TABLE #rptStatementTable(
		 CustId			INT
		,winlostdate		SMALLDATETIME	
		,OpeningTotalBalance MONEY	NULL	 
	) 
	
	BEGIN 	
		IF @Todate < @MBSaturday 
		BEGIN 
			SELECT @i = DATEPART (DW,@Todate) 	
			SELECT @MBSaturday = DATEADD ( DD, -@i, @Todate)	
		END 

		INSERT INTO #rptStatementTable (CustId, winlostdate, OpeningTotalBalance)	
		SELECT CustID, @ToDate AS winlostdate, OpeningTotalBalance
		FROM (
				SELECT t.CustID, MAX(r.winlostdate) AS winlostdate, r.OpeningTotalBalance
				FROM   #CustIds t 
				LEFT JOIN dbo.rptStatement r WITH (NOLOCK)	
					ON t.CustID = r.CustID 
				WHERE  r.Winlostdate <= @Todate
					   AND r.Winlostdate >= @MBSaturday
				GROUP BY t.CustID, r.OpeningTotalBalance
				) T			   
		

		IF @FromDate < @MBSaturday 
		BEGIN 
			SELECT @i = DATEPART (DW,@FromDate) 	
			SELECT @MBSaturday = DATEADD ( DD, -@i, @FromDate)	
		END 
		
		INSERT INTO #rptStatementTable (CustId, winlostdate, OpeningTotalBalance)	
		SELECT CustID, @FromDate AS winlostdate, OpeningTotalBalance
		FROM (
				SELECT t.CustID, MAX(r.winlostdate) AS winlostdate, r.OpeningTotalBalance
				FROM   #CustIds t 
				LEFT JOIN dbo.rptStatement r WITH (NOLOCK)	
					ON t.CustID = r.CustID 
				WHERE   r.Winlostdate <= @FromDate
						AND r.Winlostdate >= @MBSaturday
				GROUP BY t.CustID, r.OpeningTotalBalance
				) F						
	END
	
	--------IF no record of BL of FromDate, then get the nearest BL on rptStatement_old-----------------------------
			 
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