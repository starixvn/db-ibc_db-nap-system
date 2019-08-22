/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE CS_ProblemAccount_MonitorList
	@FromDate				DATETIME,
	@ToDate					DATETIME,
	@RoleId					TINYINT = 1,
	@CurrencyId			INT = 81,
	@Status					TINYINT = 0,
	@IsReduce				TINYINT = 0,
	@ReasonId				VARCHAR(50),
	@UserSearch				NVARCHAR(50) = '',
	@IsSearchDownline		BIT = 0,
	@OrderType				TINYINT = 0,
	
	@PageSize				INT = 100,
	@PageIndex				INT = 0,
	@TotalItems				INT = 0 OUTPUT
AS
/*
	Created: Elodie
	Date: 20190808
	Task : Manage problem account
	DB: DBCUST/CustDB

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]

	Parameter's explaination: 
		@IsReduce: 0:All, 1:No, 2:Yes
		@OrderType: 1:SMA line, 2:MarkDate, 3:Account Status
		@Status: 0:All, 1:Inactive, 2:Suspended, 3:View Only, 4:Active
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @CustSearchId INT, @CustSearchRoleId TINYINT
	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	DECLARE @Reason TABLE (ReasonId TINYINT)	
	CREATE TABLE #CustList (CustId INT PRIMARY KEY, HeadlineId INT, srecommend INT, mrecommend INT, recommend INT, CustStatus TINYINT, AbnormalBetNumber INT)
	CREATE TABLE #CustDetailList (CustId INT, CreateDate DATETIME, UplineId NVARCHAR(50), ReasonId TINYINT, MaxBet MONEY, AbnormalBetNumber INT DEFAULT(0))
	CREATE TABLE #Result (CustId INT, username NVARCHAR(50), Headline NVARCHAR(50), Super NVARCHAR(50), Master NVARCHAR(50), Agent NVARCHAR(50), 
			IsProblemAccSuper BIT, IsProblemAccMaster BIT, IsProblemAccAgent BIT, IsProblemAcc BIT,
			SuperMaxBet MONEY, SuperMPM MONEY, MasterMaxBet MONEY, MasterMPM MONEY, AgentMaxBet MONEY, AgentMPM MONEY, MaxBet MONEY, MPM MONEY,
			CustStatus TINYINT, MarkDate DATETIME, Comment NVARCHAR(100), AbnormalBetNumber BIT, RowNumber INT)

	SELECT @CustSearchId = CustId, @CustSearchRoleId = roleid FROM dbo.custInfo WITH (NOLOCK) WHERE username = @UserSearch

	INSERT INTO @Reason (ReasonId)	
	SELECT CAST(f.val AS TINYINT)
	FROM dbo.f_SplitString(@ReasonId, ',') f
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
					AND ci.currency = @CurrencyId
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
					AND ci.currency = @CurrencyId
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
				AND ci.currency = @CurrencyId
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
		SELECT c.CustId, MIN(tv.CreatedDate), 0, tv.SubIssueTypeId, NULL, COUNT(1)
		FROM #CustList c
			INNER JOIN dbo.TicketVoiding_VoidedTransaction tv WITH (NOLOCK) ON c.CustId = tv.custid			
		WHERE tv.CreatedDate BETWEEN @FromDate AND @ToDate AND IssueTypeId = 11
		GROUP BY c.CustId, tv.SubIssueTypeId	

		UPDATE c 
		SET c.AbnormalBetNumber = t.AbnormalBetNumber
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

	IF @OrderType = 1
	BEGIN
		INSERT INTO #Result (CustId, username, Headline, Super, Master, Agent, 
			IsProblemAccSuper, IsProblemAccMaster, IsProblemAccAgent, IsProblemAcc,
			SuperMaxBet, SuperMPM, MasterMaxBet, MasterMPM, AgentMaxBet, AgentMPM, MaxBet, MPM,
			CustStatus, MarkDate, Comment, AbnormalBetNumber, RowNumber)
		SELECT c.CustId, ci.username, hl.username AS Headline, s.username AS Super, m.username AS Master, a.username AS Agent, 
			CASE WHEN spa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccSuper,
			CASE WHEN mpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccMaster,
			CASE WHEN apa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccAgent,
			CASE WHEN cpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAcc,
			spa.MaxBet AS SuperMaxBet, spa.MaxPerEvent AS SuperMPM, mpa.MaxBet AS MasterMaxBet, mpa.MaxPerEvent AS MasterMPM, 
			apa.MaxBet AS AgentMaxBet, apa.MaxPerEvent AS AgentMPM, cpa.MaxBet AS MaxBet, cpa.MaxPerEvent AS MPM,
			c.CustStatus, cpa.CreatedDate AS MarkDate, cpa.Comment, c.AbnormalBetNumber,
			ROW_NUMBER() OVER (ORDER BY Headline, Super, Master, Agent, username, CustStatus DESC, MarkDate DESC) AS RowNumber
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
	END
	ELSE IF @OrderType = 2
	BEGIN
		INSERT INTO #Result (CustId, username, Headline, Super, Master, Agent, 
			IsProblemAccSuper, IsProblemAccMaster, IsProblemAccAgent, IsProblemAcc,
			SuperMaxBet, SuperMPM, MasterMaxBet, MasterMPM, AgentMaxBet, AgentMPM, MaxBet, MPM,
			CustStatus, MarkDate, Comment, AbnormalBetNumber, RowNumber)
		SELECT c.CustId, ci.username, hl.username AS Headline, s.username AS Super, m.username AS Master, a.username AS Agent, 
			CASE WHEN spa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccSuper,
			CASE WHEN mpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccMaster,
			CASE WHEN apa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccAgent,
			CASE WHEN cpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAcc,
			spa.MaxBet AS SuperMaxBet, spa.MaxPerEvent AS SuperMPM, mpa.MaxBet AS MasterMaxBet, mpa.MaxPerEvent AS MasterMPM, 
			apa.MaxBet AS AgentMaxBet, apa.MaxPerEvent AS AgentMPM, cpa.MaxBet AS MaxBet, cpa.MaxPerEvent AS MPM,
			c.CustStatus, cpa.CreatedDate AS MarkDate, cpa.Comment, c.AbnormalBetNumber,
			ROW_NUMBER() OVER (ORDER BY MarkDate DESC, Headline, Super, Master, Agent, username, CustStatus DESC) AS RowNumber
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
	END
	ELSE IF @OrderType = 3
	BEGIN
		INSERT INTO #Result (CustId, username, Headline, Super, Master, Agent, 
			IsProblemAccSuper, IsProblemAccMaster, IsProblemAccAgent, IsProblemAcc,
			SuperMaxBet, SuperMPM, MasterMaxBet, MasterMPM, AgentMaxBet, AgentMPM, MaxBet, MPM,
			CustStatus, MarkDate, Comment, AbnormalBetNumber, RowNumber)
		SELECT c.CustId, ci.username, hl.username AS Headline, s.username AS Super, m.username AS Master, a.username AS Agent, 
			CASE WHEN spa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccSuper,
			CASE WHEN mpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccMaster,
			CASE WHEN apa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccAgent,
			CASE WHEN cpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAcc,
			spa.MaxBet AS SuperMaxBet, spa.MaxPerEvent AS SuperMPM, mpa.MaxBet AS MasterMaxBet, mpa.MaxPerEvent AS MasterMPM, 
			apa.MaxBet AS AgentMaxBet, apa.MaxPerEvent AS AgentMPM, cpa.MaxBet AS MaxBet, cpa.MaxPerEvent AS MPM,
			c.CustStatus, cpa.CreatedDate AS MarkDate, cpa.Comment, c.AbnormalBetNumber,
			ROW_NUMBER() OVER (ORDER BY CustStatus DESC, Headline, Super, Master, Agent, username, MarkDate DESC) AS RowNumber
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
	END

	SELECT @TotalItems = COUNT(1) FROM #Result
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	SELECT *
	FROM #Result
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd 	

	SELECT cd.Custid, CreateDate, pr.ReasonName, ci.Username
	FROM #CustDetailList cd
		INNER JOIN #Result r ON cd.CustId = r.CustId
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = cd.CustId
		INNER JOIN dbo.ProblemAccountReason pr WITH (NOLOCK) ON pr.ReasonID = cd.ReasonId
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd 	

	DROP TABLE #CustDetailList
	DROP TABLE #CustList
	DROP TABLE #Result
END
GO
