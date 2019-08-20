/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE CS_ProblemAccount_CustomerList
	@FromDate				DATETIME,
	@ToDate					DATETIME,
	@RoleId					TINYINT = 1,
	@CurrrencyId			INT = 81,
	@Status					TINYINT = 0,
	@IsReduce				TINYINT = 0,
	@AbnormalBetReasonId	VARCHAR(50),
	@ManualReasonId			VARCHAR(50),
	@UserSearch				NVARCHAR(50) = '',
	@IsSearchDownline		BIT = 0,
	@OrderType				TINYINT = 0,
	
	@PageSize				INT = 100,
	@PageIndex				INT = 0,
	@TotalPages				INT = 0 OUTPUT
AS
/*
	Created: Elodie
	Date: 20190808
	Task : Manage problem account
	DB: DBCUST/CustDB

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]

	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @CustSearchId INT, @CustSearchRoleId TINYINT
	DECLARE @Reason TABLE (ReasonId TINYINT, ReasonType BIT)	
	CREATE TABLE #CustList (CustId INT PRIMARY KEY, HeadlineId INT, srecommend INT, mrecommend INT, recommend INT, CustStatus TINYINT, AbnormalBetNumber INT)
	CREATE TABLE #CustDetailList (CustId INT, CreateDate DATETIME, UplineId NVARCHAR(50), ReasonId TINYINT, MaxBet MONEY, AbnormalBetNumber INT DEFAULT(0))

	SELECT @CustSearchId = CustId, @CustSearchRoleId = roleid FROM dbo.custInfo WITH (NOLOCK) WHERE username = @UserSearch

	INSERT INTO @Reason (ReasonId, ReasonType)	
	SELECT CAST(f.val AS TINYINT), 0
	FROM dbo.f_SplitString(@AbnormalBetReasonId, ',') f
	OPTION (MAXRECURSION 0)

	INSERT INTO @Reason (ReasonId, ReasonType)	
	SELECT CAST(f.val AS TINYINT), 1
	FROM dbo.f_SplitString(@ManualReasonId, ',') f
	OPTION (MAXRECURSION 0)

	IF @CustSearchId IS NOT NULL
	BEGIN
		IF @IsSearchDownline = 0 --search by username
		BEGIN
			IF @CustSearchRoleId = @RoleId
			BEGIN
				INSERT INTO #CustList (CustId, srecommend, mrecommend, recommend, CustStatus)				
				SELECT ci.custid, ci.srecommend, ci.mrecommend, ci.recommend, st.CustStatus
				FROM dbo.CS_ProblemAccount pa WITH (NOLOCK)
					INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = pa.CustId				
					CROSS APPLY dbo.f_CS_GetCustomerStatus(ci.custid) st
				WHERE ci.custid = @CustSearchId
					AND ci.roleid = @RoleId
					AND ci.currency = @CurrrencyId
					AND pa.CreatedDate BETWEEN @FromDate AND @ToDate					
					AND st.CustStatus = CASE WHEN @Status = 0 THEN st.CustStatus ELSE @Status END
			END
		END
		ELSE --search by username's downline
		BEGIN
			IF @CustSearchRoleId > @RoleId
			BEGIN
				INSERT INTO #CustList (CustId, srecommend, mrecommend, recommend, CustStatus)				
				SELECT ci.custid, ci.srecommend, ci.mrecommend, ci.recommend, st.CustStatus
				FROM dbo.CS_ProblemAccount pa WITH (NOLOCK)
					INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = pa.CustId				
					CROSS APPLY dbo.f_CS_GetCustomerStatus(ci.custid) st
				WHERE @CustSearchId = CASE WHEN @CustSearchRoleId = 4 THEN ci.srecommend
											WHEN @CustSearchRoleId = 3 THEN ci.mrecommend
											WHEN @CustSearchRoleId = 2 THEN ci.recommend END
					AND ci.roleid = @RoleId
					AND ci.currency = @CurrrencyId
					AND pa.CreatedDate BETWEEN @FromDate AND @ToDate					
					AND st.CustStatus = CASE WHEN @Status = 0 THEN st.CustStatus ELSE @Status END
			END
		END
	END 
	ELSE
	BEGIN
			INSERT INTO #CustList (CustId, srecommend, mrecommend, recommend)				
			SELECT ci.custid, ci.srecommend, ci.mrecommend, ci.recommend
			FROM dbo.CS_ProblemAccount pa WITH (NOLOCK)
				INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = pa.CustId				
				CROSS APPLY dbo.f_CS_GetCustomerStatus(ci.custid) st
			WHERE ci.roleid = @RoleId
				AND ci.currency = @CurrrencyId
				AND pa.CreatedDate BETWEEN @FromDate AND @ToDate					
				AND st.CustStatus = CASE WHEN @Status = 0 THEN st.CustStatus ELSE @Status END
	END

	IF @RoleId <= 4
	BEGIN	
		INSERT INTO #CustDetailList (CustId, CreateDate, UplineId, ReasonId, MaxBet)
		SELECT c.CustId, pa.CreatedDate, 0, pa.ReasonId, pa.MaxBet
		FROM #CustList c
			INNER JOIN dbo.CS_ProblemAccount pa WITH (NOLOCK) ON c.CustId = pa.CustId	
	END
	
	IF @RoleId <= 3
	BEGIN
		INSERT INTO #CustDetailList (CustId, CreateDate, UplineId, ReasonId, MaxBet)
		SELECT c.CustId, pa.CreatedDate, 0, pa.ReasonId, pa.MaxBet
		FROM #CustList c
			INNER JOIN dbo.CS_ProblemAccount pa WITH (NOLOCK) ON c.srecommend = pa.CustId	
	END

	IF @RoleId <= 2
	BEGIN
		INSERT INTO #CustDetailList (CustId, CreateDate, UplineId, ReasonId, MaxBet)
		SELECT c.CustId, pa.CreatedDate, 0, pa.ReasonId, pa.MaxBet
		FROM #CustList c
			INNER JOIN dbo.CS_ProblemAccount pa WITH (NOLOCK) ON c.mrecommend = pa.CustId	
	END

	IF @RoleId = 1
	BEGIN
		INSERT INTO #CustDetailList (CustId, CreateDate, UplineId, ReasonId, MaxBet)
		SELECT c.CustId, pa.CreatedDate, 0, pa.ReasonId, pa.MaxBet
		FROM #CustList c
			INNER JOIN dbo.CS_ProblemAccount pa WITH (NOLOCK) ON c.recommend = pa.CustId

		INSERT INTO #CustDetailList (CustId, CreateDate, UplineId, ReasonId, MaxBet, AbnormalBetNumber)
		SELECT c.CustId, MIN(tv.CreateDate), 0, tv.SubIssueTypeId, NULL, COUNT(1)
		FROM #CustList c
			INNER JOIN dbo.TicketVoiding_VoidedTransaction tv WITH (NOLOCK) ON c.CustId = tv.custid			
		WHERE tv.CreatedDate BETWEEN @FromDate AND @ToDate AND IssueTypeId = 11
		GROUP BY c.CustId, tv.SubIssueTypeId	

		UPDATE c 
		SET c.AbnormalBetNumber = SUM(t.AbnormalBetNumber)
		FROM #CustList c
			INNER JOIN (SELECT custid, SUM(AbnormalBetNumber) AS AbnormalBetNumber
						FROM #CustDetailList 
						GROUP BY custid) AS t ON c.CustId = t.custid
	END

	DELETE c 
	FROM #CustList c 
	WHERE custid NOT IN (	SELECT DISTINCT custid
							FROM #CustDetailList cd 
							WHERE cd.ReasonId IN (SELECT ReasonId FROM @Reason))
		OR (custid IN(	SELECT DISTINCT custid
						FROM #CustDetailList cd 
						WHERE cd.MaxBet IS NOT NULL) AND @IsReduce = 1								
				)
		OR (custid NOT IN(	SELECT DISTINCT custid
							FROM #CustDetailList cd 
							WHERE cd.MaxBet IS NOT NULL) AND @IsReduce = 2								
				)
	
	DELETE cd 
	FROM #CustDetailList cd
	WHERE NOT EXISTS (SELECT 1 FROM #CustList WHERE CustId = cd.CustId)

	UPDATE c 
	SET c.HeadlineId = s.UplineId	 
	FROM #CustList c
		INNER JOIN dbo.CustSuper s WITH (NOLOCK) ON c.srecommend = s.custid	

	SELECT c.CustId, ci.username, hl.username AS Headline, s.username AS Super, m.username AS Master, a.username AS Agent, 
		CASE WHEN spa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccSuper,
		CASE WHEN mpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccMaster,
		CASE WHEN apa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccAgent,
		CASE WHEN cpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAcc,
		spa.MaxBet AS SuperMaxBet, spa.MaxPerEvent AS SuperMPM, mpa.MaxBet AS MasterMaxBet, mpa.MaxPerEvent AS MasterMPM, 
		apa.MaxBet AS AgentMaxBet, apa.MaxPerEvent AS AgentMPM, cpa.MaxBet AS MaxBet, cpa.MaxPerEvent AS MPM,
		c.CustStatus, cpa.CreatedDate AS MarkDate, cpa.Comment, c.AbnormalBetNumber
	FROM #CustList c
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = c.HeadlineId
		INNER JOIN dbo.custInfo hl WITH (NOLOCK) ON hl.custid = c.HeadlineId
		INNER JOIN dbo.custInfo s WITH (NOLOCK) ON s.custid = c.srecommend
		INNER JOIN dbo.custInfo m WITH (NOLOCK) ON m.custid = c.mrecommend
		INNER JOIN dbo.custInfo a WITH (NOLOCK) ON a.custid = c.recommend
		INNER JOIN dbo.CS_ProblemAccount cpa WITH (NOLOCK) ON c.custid = cpa.CustId
		LEFT JOIN dbo.CS_ProblemAccount spa WITH (NOLOCK) ON s.custid = spa.CustId
		LEFT JOIN dbo.CS_ProblemAccount mpa WITH (NOLOCK) ON m.custid = mpa.CustId
		LEFT JOIN dbo.CS_ProblemAccount apa WITH (NOLOCK) ON a.custid = apa.CustId


	SELECT cd.Custid, CreateDate, pr.ReasonName, ci.Username
	FROM #CustDetailList cd
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = cd.CustId
		INNER JOIN dbo.ProblemAccountReason pr WITH (NOLOCK) ON pr.ReasonID = cd.ReasonId
END
GO
