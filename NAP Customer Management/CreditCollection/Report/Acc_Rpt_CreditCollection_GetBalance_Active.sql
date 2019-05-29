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
		SELECT c.CustID, @ToDate AS Winlostdate, r.OpeningTotalBalance 
		FROM  #CustIds c
		LEFT JOIN 
			(	
				SELECT CustID, Winlostdate, OpeningTotalBalance, ROW_NUMBER() OVER (PARTITION BY CustID ORDER BY  Winlostdate DESC) as Num
				FROM   dbo.rptTotalBalance_Active WITH (NOLOCK) 
				WHERE  Winlostdate <= @Todate
				GROUP BY CustID, Winlostdate, OpeningTotalBalance		
			) r
			ON c.CustID = r.CustId AND r.Num = 1
				
		INSERT INTO #rptStatementTable (CustId, winlostdate, OpeningTotalBalance)			
		SELECT c.CustID, @FromDate AS Winlostdate, r.OpeningTotalBalance 
		FROM  #CustIds c
		LEFT JOIN (		
						SELECT CustID, Winlostdate, OpeningTotalBalance, ROW_NUMBER() OVER (PARTITION BY CustID ORDER BY  Winlostdate DESC) as Num
						FROM   dbo.rptTotalBalance_Active WITH (NOLOCK) 
						WHERE  Winlostdate <= @FromDate
						GROUP BY CustID, Winlostdate, OpeningTotalBalance		
					) r
		ON c.CustID = r.CustId AND r.Num = 1
	   
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
		SELECT	t.CustId, @FromDate AS Winlostdate, r.OpeningTotalBalance
		FROM 	
			(	SELECT	CustId
				FROM	#rptStatementTable 
				WHERE 	OpeningTotalBalance IS NULL
						AND winlostdate = @FromDate
			) t	
		LEFT JOIN 
			(	
				SELECT CustID, Winlostdate, OpeningTotalBalance, ROW_NUMBER() OVER (PARTITION BY CustID ORDER BY  Winlostdate DESC) as Num
				FROM   dbo.rptStatement WITH (NOLOCK) 
				WHERE  Winlostdate >= @MBSaturday
				GROUP BY CustID, Winlostdate, OpeningTotalBalance						
			) r
			ON t.CustID = r.CustID AND r.Num = 1
		
		
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
		SELECT	t.CustId, @FromDate As Winlostdate, r.OpeningTotalBalance
		FROM 	
			(	SELECT	CustId
				FROM	#rptStatementTable 
				WHERE 	OpeningTotalBalance IS NULL
						AND winlostdate = @FromDate
			) t	
		LEFT JOIN 
			(	SELECT CustID, Winlostdate, OpeningTotalBalance, ROW_NUMBER() OVER (PARTITION BY CustID ORDER BY  Winlostdate DESC) as Num
				FROM   dbo.rptStatement_Old WITH (NOLOCK) 
				WHERE  Winlostdate >= @BUSaturday				
			) r
			ON t.CustID = r.CustID AND r.Num =1
		
		
		
		;WITH tmpDel AS (		
							SELECT CustID, Count (1) as Cnt
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