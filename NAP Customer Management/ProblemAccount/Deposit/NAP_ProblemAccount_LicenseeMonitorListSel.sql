/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_ProblemAccount_LicenseeMonitorListSel]
	@FromDate 	DATETIME,
	@ToDate 	DATETIME,
	@Type		TINYINT = 0,
	@Vip		TINYINT = 0,
	@Currency 	INT = 0,
	@isReduced 	TINYINT =0,
	@ActionID	TINYINT=0,
	@Username 	VARCHAR(50) = '',
	@Licensee 	VARCHAR(20) = '',
	@ReasonList VARCHAR(MAX) = '',
	
	@PageSize	INT = 100,
	@PageIndex	INT = 1,
	@TotalItems	INT = 0 OUTPUT
AS
/*
	Created: Johnson
	Date: 20200217
	Task : get problem accounts for deposit
	DB: DBACC/bodb02

	Revisions:
		- 20200217@Johnson: Initial SP [Redmine:#128077]
		- 20200414@Elodie: Problem account that was abnormal voided does not show in monitor list [Redmine:#132493]
		- 20200721@Johnson: add void time & limit amount [redmine:#135253]
	Parameter's explaination: 
		- @Type: 0:All, 1:Acknowledgement, 2:Not Acknowledgement	
		- @Vip: 0:All, 1:Yes, 2:No	
		- @currency: 0;All, <>0: currencyID
		- @isReduced: 0:All, 1:No, 2:Yes	
		- Preventive ActionID: 0:All, 1: None, 2:Void all tickets, 3: Void winning tickets
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tblCust (custid INT, srecommend INT, isVip BIT, MarkDate DATETIME, ActionID TINYINT, AbnormalBetNumber INT, IsAbnormalMember BIT)
	CREATE TABLE #tblCustReason (CustId INT, CreatedDate DATETIME, ReasonId INT, AbnormalBetNumber INT)
	
	DECLARE @tmpReason TABLE (reasonID INT)
	DECLARE @tmpLicensee TABLE(LicenseeID INT, LicenseeName VARCHAR(50), isAcknowledgement BIT)
	DECLARE @tmpSuper TABLE(custid INT, site VARCHAR(50))
	DECLARE @Result TABLE(custid INT, isVip BIT, ActionID TINYINT, AbnormalBetNumber INT, site VARCHAR(50), rn INT)
	DECLARE @Rowstart INT, @RowEnd INT
	
	IF @Licensee = ''
		SELECT @Licensee = NULL	
	IF @currency = 0	
		SELECT @currency = NULL
	IF @ActionID = 0
		SELECT @ActionID = NULL	
		
	INSERT INTO @tmpReason(reasonID)
	SELECT val
	FROM strSplit (@ReasonList,',')
	
	INSERT INTO @tmpLicensee(LicenseeID,LicenseeName,isAcknowledgement)
	SELECT LicenseeID,LicenseeName, isAcknowledgement
	FROM(
		SELECT LicenseeID,LicenseeName, ISNULL(isAcknowledgement,0) isAcknowledgement
		FROM bodb_licensee.dbo.Licensees WITH(NOLOCK)
		WHERE LicenseeName LIKE '%'+ISNULL(@Licensee,LicenseeName) + '%'
			AND isActive = 1
	)t
	WHERE 1 = CASE WHEN @Type = 1 AND isAcknowledgement = 1 THEN 1
					WHEN @Type = 2 AND isAcknowledgement = 0 THEN 1
					WHEN @Type = 0 THEN 1 ELSE 0 END
		
	INSERT INTO @tmpSuper (custid,site)
	SELECT custid,site
	FROM Dep_CustSuper WITH(NOLOCK)
	WHERE site IN (SELECT LicenseeName FROM @tmpLicensee)
		AND currency = ISNULL(@currency,currency)
	
	IF @Username <> ''
	BEGIN
		;WITH t as (
		SELECT c.custid,c.srecommend, CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END isVip,
			p.MaxBet,ActionID,p.CreatedDate as MarkDate, p.IsAbnormalMember
		FROM customer c WITH(NOLOCK)
			INNER JOIN ProblemAccount p WITH(NOLOCK) ON c.custid = p.custid
			LEFT JOIN Dep_CustVip d WITH(NOLOCK) ON c.custid = d.custid
		WHERE (username = @username OR username2 LIKE '%$'+@username)
			AND srecommend IN (SELECT custid FROM @tmpSuper)
			AND p.CreatedDate BETWEEN @FromDate AND @ToDate
			AND roleid = 1
		)
		INSERT INTO #tblCust(custid,srecommend,isVip,ActionID,MarkDate,IsAbnormalMember)
		SELECT custid,srecommend,isVip,ActionID,MarkDate, t.IsAbnormalMember
		FROM t
		WHERE isVip = CASE WHEN @Vip = 1 THEN 1
							WHEN @Vip = 2 THEN 0 ELSE isVip END
			AND ActionID = ISNULL(@ActionID,ActionID)
			AND 1 = CASE WHEN @isReduced = 1 AND MaxBet IS NULL THEN 1
						WHEN @isReduced = 2 AND MaxBet IS NOT NULL THEN 1
						WHEN @isReduced = 0 THEN 1 ELSE 0 END
	END
	ELSE
	BEGIN
		;WITH t as (
		SELECT c.custid,c.srecommend,CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END isVip,
			p.MaxBet,p.ActionID,p.CreatedDate as MarkDate, p.IsAbnormalMember
		FROM customer c WITH(NOLOCK)
			INNER JOIN ProblemAccount p WITH(NOLOCK) ON c.custid = p.custid
			LEFT JOIN Dep_CustVip d WITH(NOLOCK) ON c.custid = d.custid
		WHERE srecommend IN (SELECT custid FROM @tmpSuper)
			AND p.CreatedDate BETWEEN @FromDate AND @ToDate
			AND roleid = 1
		)
		INSERT INTO #tblCust(custid,srecommend,isVip,ActionID,MarkDate, IsAbnormalMember)
		SELECT custid,srecommend,isVip,ActionID,MarkDate, t.IsAbnormalMember
		FROM t
		WHERE isVip = CASE WHEN @Vip = 1 THEN 1
							WHEN @Vip = 2 THEN 0 ELSE isVip END
			AND ActionID = ISNULL(@ActionID,ActionID)
			AND 1 = CASE WHEN @isReduced = 1 AND MaxBet IS NULL THEN 1
						WHEN @isReduced = 2 AND MaxBet IS NOT NULL THEN 1
						WHEN @isReduced = 0 THEN 1 ELSE 0 END
	END
				
	INSERT INTO #tblCustReason (CustId, CreatedDate, ReasonId, AbnormalBetNumber)
	SELECT c.CustId, MIN(tv.CreatedDate), tv.SubIssueTypeId, COUNT(1)
	FROM #tblCust c
		INNER JOIN dbo.TicketVoiding_VoidedTransaction tv WITH (NOLOCK) ON c.CustId = tv.custid			
	WHERE tv.CreatedDate BETWEEN @FromDate AND @ToDate
		 AND IssueTypeId = 11
	GROUP BY c.CustId, tv.SubIssueTypeId
	UNION ALL
	SELECT c.custid, p.CreatedDate, p.ReasonId,0
	FROM #tblCust c
		INNER JOIN ProblemAccount p WITH(NOLOCK) ON c.custid = p.custid
	
	INSERT INTO #tblCustReason (CustId, CreatedDate, ReasonId, AbnormalBetNumber)
	SELECT c.CustId, NULL, 0, 0
	FROM #tblCust c
	WHERE NOT EXISTS (SELECT 1 FROM dbo.TicketVoiding_VoidedTransaction tv WITH (NOLOCK) WHERE c.CustId = tv.custid AND tv.IssueTypeID = 11)
		AND c.IsAbnormalMember = 1

	UPDATE c 
	SET c.AbnormalBetNumber = t.AbnormalBetNumber
	FROM #tblCust c
		INNER JOIN (SELECT custid, SUM(AbnormalBetNumber) AS AbnormalBetNumber
					FROM #tblCustReason t 
					GROUP BY custid) AS t ON c.CustId = t.custid
					
	DELETE c 
	FROM #tblCust c 
	WHERE custid NOT IN (	SELECT DISTINCT custid
							FROM #tblCustReason cs
							WHERE cs.ReasonId IN (SELECT ReasonId FROM @tmpReason))
	
	DELETE #tblCustReason
	WHERE custid NOT IN (SELECT custid FROM #tblCust)
	
	SELECT @TotalItems = COUNT(1) FROM #tblCust
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 
	
	;WITH t AS (
	SELECT c.custid,c.isVip,c.ActionID,c.AbnormalBetNumber,s.site, ROW_NUMBER() OVER (ORDER BY s.site ASC, c.MarkDate DESC) rn
	FROM #tblCust c
		INNER JOIN @tmpSuper s ON c.srecommend = s.custid
	)
	INSERT INTO @Result(custid,isVip,ActionID,AbnormalBetNumber,site,rn)
	SELECT custid,isVip,ActionID,AbnormalBetNumber,site,rn
	FROM t 		
	WHERE rn BETWEEN @RowStart AND @RowEnd
	
	SELECT rs.custid, rs.site, l.isAcknowledgement, c.username, 
		SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) AS username2,
		e.currency, rs.isVip, a.ActionName, p.MaxBet, p.MaxPerEvent as MaxPerMatch, p.CreatedDate as MarkDate, p.comment,
		p.VoidTime, p.LimitAmount, inform1.username as inform1, inform2.username as inform2, rs.AbnormalBetNumber
	FROM @Result rs
		INNER JOIN customer c WITH(NOLOCK) ON rs.custid = c.custid
		INNER JOIN Exchange e WITH(NOLOCK) ON c.currency = e.exchangeid 
		INNER JOIN ProblemAccount p WITH(NOLOCK) ON rs.custid = p.custid
		INNER JOIN @tmpLicensee l ON rs.site = l.LicenseeName
		LEFT JOIN ProblemAccountAction a WITH(NOLOCK) ON rs.ActionID = a.ActionID
		LEFT JOIN custinfo inform1 WITH(NOLOCK) ON p.Informed1By = inform1.custid
		LEFT JOIN custinfo inform2 WITH(NOLOCK) ON p.Informed2By = inform2.custid
	ORDER BY rn ASC
	
	SELECT rs.rn, c.custid, c.CreatedDate, pr.ReasonName
	FROM @Result rs
		INNER JOIN #tblCustReason c ON rs.custid = c.custid
		INNER JOIN dbo.ProblemAccountReason pr WITH (NOLOCK) ON pr.ReasonID = c.ReasonId
	ORDER BY rn ASC, custid, CreatedDate DESC 	
END

GO
