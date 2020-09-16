/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_ProblemAccount_VoidedTransactionList]
	@CustId		INT
	,@FromDate	DATETIME
	,@ToDate	DATETIME
	,@PageIndex	INT = 1
	,@PageSize	INT = 50
	,@TotalRows	INT = 0 OUTPUT
AS

/*
	Created: 20200205@Percy
	DB: DBACC.bodb02
	Task: Customer Management - Problem Account - Voided Transaction List (CN88: CS_ProblemAccount_VoidedTransactionList)

	Revisions:
		- 20200205@Percy: Initialize SP [RedmineID: #127446]
		- 20200916@Johnson: get archive data for TicketVoiding_VoidedTransaction [redmine:#137217]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart INT, @RowEnd INT

	SELECT  @RowStart	= @PageSize * (@PageIndex - 1) + 1
			,@RowEnd	= @RowStart + @PageSize - 1
	
	CREATE TABLE #tmpTicketVoiding (TransID BIGINT, CreatedDate DATETIME, SubIssueTypeName VARCHAR(100))
	
	;WITH T AS (
		SELECT TransID,CreatedDate,SubIssueTypeName
		FROM dbo.TicketVoiding_VoidedTransaction t WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_SubIssueType s WITH (NOLOCK) ON t.SubIssueTypeID = s.SubIssueTypeID
		WHERE t.CreatedDate BETWEEN @FromDate AND @ToDate
			AND t.CustID = @CustId
			AND t.IssueTypeId = 11 -- Abnormal Bets
		UNION 	
		SELECT TransID,CreatedDate,SubIssueTypeName
		FROM DBARC.bodb_Archive.dbo.TicketVoiding_VoidedTransaction_bk t WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_SubIssueType s WITH (NOLOCK) ON t.SubIssueTypeID = s.SubIssueTypeID
		WHERE t.CreatedDate BETWEEN @FromDate AND @ToDate
			AND t.CustID = @CustId
			AND t.IssueTypeId = 11 -- Abnormal Bets
	)
	INSERT INTO #tmpTicketVoiding (TransID,CreatedDate,SubIssueTypeName)
	SELECT DISTINCT TransID,CreatedDate,SubIssueTypeName
	FROM T
	
	SELECT @TotalRows = COUNT(1)
	FROM #tmpTicketVoiding

	SELECT CreatedDate, TransId, AbnormalReason
	FROM (
		SELECT t.CreatedDate, t.TransId, t.SubIssueTypeName AS AbnormalReason, ROW_NUMBER() OVER(ORDER BY t.CreatedDate DESC) AS RowNum
		FROM #tmpTicketVoiding t
	) AS A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd
	ORDER BY A.RowNum
	
	DROP TABLE #tmpTicketVoiding
END
GO