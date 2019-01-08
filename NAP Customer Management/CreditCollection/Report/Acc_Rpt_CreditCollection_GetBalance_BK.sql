/*<info serverAlias="DBRPT-bodb_report" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/

ALTER PROCEDURE [dbo].[Acc_Rpt_CreditCollection_GetBalance_BK]
	@FromDate	DATE,
	@ToDate		DATE,
	@CustIDList	VARCHAR(MAX)
AS
/*  Created: Sophia  
	Date:	20181206
	DB:		DBRPT-bodb_report
	Task :  Get Balance for List Customer - Level Super - Bettrans_BK Range [Redmine: 98621]
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
		INSERT INTO #rptStatementTable (OwnerID, winlostdate, OpeningBalance, ClosingBalance)		
		SELECT r.CustID, r.winlostdate, r.OpeningBalance, r.ClosingBalance
		FROM bodb_Report.dbo.rptStatement_Old r WITH (NOLOCK)		
		WHERE Winlostdate IN (@FromDate, @ToDate)
			AND EXISTS (SELECT 1 FROM #CustIds c WHERE c.CustID = r.custid)
		ORDER BY r.CustID, r.winlostdate   
						
	END
	-- End Super --
	
	
 	SELECT r.OwnerID  
		,  CASE WHEN r.WinlostDate = @ToDate THEN DATEADD(dd, 1, @ToDate) ELSE @FromDate END AS WinlostDate
		, SUM (CASE WHEN r.Winlostdate = @FromDate THEN ISNULL(r.OpeningBalance, 0) * e.ActualRate ELSE ISNULL(r.ClosingBalance, 0) * e.ActualRate END ) AS OpeningBalance 
	FROM #rptStatementTable r
		INNER JOIN bodb02.dbo.Customer m WITH (NOLOCK) 
				ON m.CustID = r.OwnerID	
		INNER JOIN bodb02.dbo.ExchangeDailyOanda e WITH (NOLOCK) 
			ON e.ExchangeId = m.currency and e.ExchangeDate = r.WinlostDate
	GROUP BY r.WinlostDate, r.OwnerID  
	

	DROP TABLE #rptStatementTable
	DROP TABLE #CustIds

END

GO 

