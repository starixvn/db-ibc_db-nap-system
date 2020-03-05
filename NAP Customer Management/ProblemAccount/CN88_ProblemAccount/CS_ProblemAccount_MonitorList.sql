/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE CS_ProblemAccount_MonitorList
	@FromDate				DATETIME,
	@ToDate					DATETIME,
	@RoleId					TINYINT = 1,
	@CurrencyId				INT = 81,
	@Status					TINYINT = 0,
	@IsReduce				TINYINT = 0,
	@ReasonId				VARCHAR(MAX),
	@UserSearch				NVARCHAR(50) = '',
	@IsSearchDownline		BIT = 0,
	@OrderType				TINYINT = 1,
	@IsDirectlyMarked		TINYINT = 0,
	
	@PageSize				INT = 100,
	@PageIndex				INT = 1,
	@TotalItems				INT = 0 OUTPUT
AS
/*
	Created: Elodie
	Date: 20190808
	Task : Manage problem account
	DB: DBACC/bodb02

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]
		- 20190808@Elodie: Change datatype of @ReasonId parameter [Redmine:#126080]
		- 20191230@Johnson: filter by directly marked [redmine:#121298]
	Parameter's explaination: 
		@IsReduce: 0:All, 1:No, 2:Yes
		@OrderType: 1:SMA line, 2:MarkDate, 3:Account Status
		@Status: 0:All, 1:Inactive, 2:Suspended, 3:View Only, 4:Active
		@IsDirectlyMarked: 0: All, 1: No, 2: Yes
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @CustSearchId INT, @CustSearchRoleId TINYINT
	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	DECLARE @Reason TABLE (ReasonId TINYINT)	
	CREATE TABLE #CustList (CustId INT PRIMARY KEY, HeadlineId INT, srecommend INT, mrecommend INT, recommend INT, CustStatus TINYINT, AbnormalBetNumber INT, IsDirectlyMarked BIT, IsAbnormalMember BIT)
	CREATE TABLE #CustDetailList (CustId INT, CreateDate DATETIME, UplineId NVARCHAR(50), ReasonId TINYINT, MaxBet MONEY, AbnormalBetNumber INT DEFAULT(0))
	CREATE TABLE #Result (CustId INT, username NVARCHAR(50), Headline NVARCHAR(50), Super NVARCHAR(50), Master NVARCHAR(50), Agent NVARCHAR(50), 
			IsProblemAccSuper BIT, IsProblemAccMaster BIT, IsProblemAccAgent BIT, IsProblemAcc BIT,
			SuperMaxBet MONEY, SuperMPM MONEY, MasterMaxBet MONEY, MasterMPM MONEY, AgentMaxBet MONEY, AgentMPM MONEY, MaxBet MONEY, MPM MONEY,
			CustStatus TINYINT, MarkDate DATETIME, Comment NVARCHAR(100), AbnormalBetNumber INT, informed1By NVARCHAR(50), informed2By NVARCHAR(50), RowNumber INT)	

	INSERT INTO @Reason (ReasonId)	
	SELECT CAST(f.val AS TINYINT)
	FROM dbo.f_SplitString(@ReasonId, ',') f
	OPTION (MAXRECURSION 0)	

	IF ISNULL(@UserSearch,'') <> '' 
	BEGIN
		SELECT @CustSearchId = CustId, @CustSearchRoleId = roleid FROM dbo.custInfo WITH (NOLOCK) WHERE username = @UserSearch

		IF @CustSearchId IS NOT NULL
		BEGIN
			IF @IsSearchDownline = 0 --search by username
			BEGIN
				IF @CustSearchRoleId = @RoleId
				BEGIN
					INSERT INTO #CustList (CustId, srecommend, mrecommend, recommend, CustStatus, IsDirectlyMarked, IsAbnormalMember)				
					SELECT ci.custid, ci.srecommend, ci.mrecommend, ci.recommend, st.CustStatus, cast(pa.ProblemStatus&POWER(2,ci.roleid-1) AS BIT), pa.IsAbnormalMember
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
					INSERT INTO #CustList (CustId, srecommend, mrecommend, recommend, CustStatus, IsDirectlyMarked, IsAbnormalMember)				
					SELECT ci.custid, ci.srecommend, ci.mrecommend, ci.recommend, st.CustStatus, cast(pa.ProblemStatus&POWER(2,ci.roleid-1) AS BIT), pa.IsAbnormalMember
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
	END 
	ELSE
	BEGIN
		INSERT INTO #CustList (CustId, srecommend, mrecommend, recommend, CustStatus, IsDirectlyMarked, IsAbnormalMember)				
			SELECT ci.custid, ci.srecommend, ci.mrecommend, ci.recommend, st.CustStatus, cast(pa.ProblemStatus&POWER(2,ci.roleid-1) AS BIT), pa.IsAbnormalMember
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
		SELECT c.CustId, pa.CreatedDate, c.srecommend, pa.ReasonId, pa.MaxBet
		FROM #CustList c
			INNER JOIN dbo.CS_ProblemAccount pa WITH (NOLOCK) ON c.srecommend = pa.CustId	
	END

	IF @RoleId <= 2
	BEGIN
		INSERT INTO #CustDetailList (CustId, CreateDate, UplineId, ReasonId, MaxBet)
		SELECT c.CustId, pa.CreatedDate, c.mrecommend, pa.ReasonId, pa.MaxBet
		FROM #CustList c
			INNER JOIN dbo.CS_ProblemAccount pa WITH (NOLOCK) ON c.mrecommend = pa.CustId	
	END

	IF @RoleId = 1
	BEGIN
		INSERT INTO #CustDetailList (CustId, CreateDate, UplineId, ReasonId, MaxBet)
		SELECT c.CustId, pa.CreatedDate, c.recommend, pa.ReasonId, pa.MaxBet
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
		OR (1= CASE WHEN @IsDirectlyMarked = 1 AND (IsDirectlyMarked = 1 OR IsAbnormalMember = 1) THEN 1
					WHEN @IsDirectlyMarked = 2 AND (IsDirectlyMarked = 0 AND IsAbnormalMember = 0) THEN 1 ELSE 0 END)
					
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
			CustStatus, MarkDate, Comment, AbnormalBetNumber, informed1By, informed2By, RowNumber)
		SELECT c.CustId, ci.username, hl.username AS Headline, s.username AS Super, m.username AS Master, a.username AS Agent, 
			CASE WHEN spa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccSuper,
			CASE WHEN mpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccMaster,
			CASE WHEN apa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccAgent,
			CASE WHEN cpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAcc,
			spa.MaxBet AS SuperMaxBet, spa.MaxPerEvent AS SuperMPM, mpa.MaxBet AS MasterMaxBet, mpa.MaxPerEvent AS MasterMPM, 
			apa.MaxBet AS AgentMaxBet, apa.MaxPerEvent AS AgentMPM, cpa.MaxBet AS MaxBet, cpa.MaxPerEvent AS MPM,
			c.CustStatus, cpa.CreatedDate AS MarkDate, cpa.Comment, c.AbnormalBetNumber, inform1.username as Informed1By, inform2.username as Informed2By,
			ROW_NUMBER() OVER (ORDER BY hl.username, s.username, m.username, a.username, ci.username, c.CustStatus DESC, cpa.CreatedDate DESC) AS RowNumber
		FROM #CustList c
			INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = c.custid
			LEFT JOIN dbo.custInfo hl WITH (NOLOCK) ON hl.custid = c.HeadlineId
			LEFT JOIN dbo.custInfo s WITH (NOLOCK) ON s.custid = c.srecommend
			LEFT JOIN dbo.custInfo m WITH (NOLOCK) ON m.custid = c.mrecommend
			LEFT JOIN dbo.custInfo a WITH (NOLOCK) ON a.custid = c.recommend
			INNER JOIN dbo.CS_ProblemAccount cpa WITH (NOLOCK) ON c.custid = cpa.CustId
			LEFT JOIN dbo.custinfo inform1 WITH(NOLOCK) ON inform1.custid = cpa.Informed1By
			LEFT JOIN dbo.custinfo inform2 WITH(NOLOCK) ON inform2.custid = cpa.Informed2By
			LEFT JOIN dbo.CS_ProblemAccount spa WITH (NOLOCK) ON s.custid = spa.CustId
			LEFT JOIN dbo.CS_ProblemAccount mpa WITH (NOLOCK) ON m.custid = mpa.CustId
			LEFT JOIN dbo.CS_ProblemAccount apa WITH (NOLOCK) ON a.custid = apa.CustId
	END
	ELSE IF @OrderType = 2
	BEGIN
		INSERT INTO #Result (CustId, username, Headline, Super, Master, Agent, 
			IsProblemAccSuper, IsProblemAccMaster, IsProblemAccAgent, IsProblemAcc,
			SuperMaxBet, SuperMPM, MasterMaxBet, MasterMPM, AgentMaxBet, AgentMPM, MaxBet, MPM,
			CustStatus, MarkDate, Comment, AbnormalBetNumber,Informed1By,Informed2By, RowNumber)
		SELECT c.CustId, ci.username, hl.username AS Headline, s.username AS Super, m.username AS Master, a.username AS Agent, 
			CASE WHEN spa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccSuper,
			CASE WHEN mpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccMaster,
			CASE WHEN apa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccAgent,
			CASE WHEN cpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAcc,
			spa.MaxBet AS SuperMaxBet, spa.MaxPerEvent AS SuperMPM, mpa.MaxBet AS MasterMaxBet, mpa.MaxPerEvent AS MasterMPM, 
			apa.MaxBet AS AgentMaxBet, apa.MaxPerEvent AS AgentMPM, cpa.MaxBet AS MaxBet, cpa.MaxPerEvent AS MPM,
			c.CustStatus, cpa.CreatedDate AS MarkDate, cpa.Comment, c.AbnormalBetNumber,
			inform1.username as Informed1By, inform2.username as Informed2By,
			ROW_NUMBER() OVER (ORDER BY cpa.CreatedDate DESC, hl.username, s.username, m.username, a.username, ci.username, c.CustStatus DESC) AS RowNumber
		FROM #CustList c
			INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = c.custid
			LEFT JOIN dbo.custInfo hl WITH (NOLOCK) ON hl.custid = c.HeadlineId
			LEFT JOIN dbo.custInfo s WITH (NOLOCK) ON s.custid = c.srecommend
			LEFT JOIN dbo.custInfo m WITH (NOLOCK) ON m.custid = c.mrecommend
			LEFT JOIN dbo.custInfo a WITH (NOLOCK) ON a.custid = c.recommend
			INNER JOIN dbo.CS_ProblemAccount cpa WITH (NOLOCK) ON c.custid = cpa.CustId
			LEFT JOIN dbo.custinfo inform1 WITH(NOLOCK) ON inform1.custid = cpa.Informed1By
			LEFT JOIN dbo.custinfo inform2 WITH(NOLOCK) ON inform2.custid = cpa.Informed2By
			LEFT JOIN dbo.CS_ProblemAccount spa WITH (NOLOCK) ON s.custid = spa.CustId
			LEFT JOIN dbo.CS_ProblemAccount mpa WITH (NOLOCK) ON m.custid = mpa.CustId
			LEFT JOIN dbo.CS_ProblemAccount apa WITH (NOLOCK) ON a.custid = apa.CustId
	END
	ELSE IF @OrderType = 3
	BEGIN
		INSERT INTO #Result (CustId, username, Headline, Super, Master, Agent, 
			IsProblemAccSuper, IsProblemAccMaster, IsProblemAccAgent, IsProblemAcc,
			SuperMaxBet, SuperMPM, MasterMaxBet, MasterMPM, AgentMaxBet, AgentMPM, MaxBet, MPM,
			CustStatus, MarkDate, Comment, AbnormalBetNumber,Informed1By,Informed2By, RowNumber)
		SELECT c.CustId, ci.username, hl.username AS Headline, s.username AS Super, m.username AS Master, a.username AS Agent, 
			CASE WHEN spa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccSuper,
			CASE WHEN mpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccMaster,
			CASE WHEN apa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAccAgent,
			CASE WHEN cpa.custid IS NULL THEN 0 ELSE 1 END AS IsProblemAcc,
			spa.MaxBet AS SuperMaxBet, spa.MaxPerEvent AS SuperMPM, mpa.MaxBet AS MasterMaxBet, mpa.MaxPerEvent AS MasterMPM, 
			apa.MaxBet AS AgentMaxBet, apa.MaxPerEvent AS AgentMPM, cpa.MaxBet AS MaxBet, cpa.MaxPerEvent AS MPM,
			c.CustStatus, cpa.CreatedDate AS MarkDate, cpa.Comment, c.AbnormalBetNumber,
			inform1.username as Informed1By, inform2.username as Informed2By,
			ROW_NUMBER() OVER (ORDER BY c.CustStatus DESC, hl.username, s.username, m.username, a.username, ci.username, cpa.CreatedDate DESC) AS RowNumber
		FROM #CustList c
			INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = c.custid
			LEFT JOIN dbo.custInfo hl WITH (NOLOCK) ON hl.custid = c.HeadlineId
			LEFT JOIN dbo.custInfo s WITH (NOLOCK) ON s.custid = c.srecommend
			LEFT JOIN dbo.custInfo m WITH (NOLOCK) ON m.custid = c.mrecommend
			LEFT JOIN dbo.custInfo a WITH (NOLOCK) ON a.custid = c.recommend
			INNER JOIN dbo.CS_ProblemAccount cpa WITH (NOLOCK) ON c.custid = cpa.CustId
			LEFT JOIN dbo.custinfo inform1 WITH(NOLOCK) ON inform1.custid = cpa.Informed1By
			LEFT JOIN dbo.custinfo inform2 WITH(NOLOCK) ON inform2.custid = cpa.Informed2By
			LEFT JOIN dbo.CS_ProblemAccount spa WITH (NOLOCK) ON s.custid = spa.CustId
			LEFT JOIN dbo.CS_ProblemAccount mpa WITH (NOLOCK) ON m.custid = mpa.CustId
			LEFT JOIN dbo.CS_ProblemAccount apa WITH (NOLOCK) ON a.custid = apa.CustId
	END

	SELECT @TotalItems = COUNT(1) FROM #Result
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	SELECT *
	FROM #Result
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd 	
	ORDER BY RowNumber

	SELECT cd.Custid, CreateDate, pr.ReasonName, ci.Username
	FROM #CustDetailList cd
		INNER JOIN #Result r ON cd.CustId = r.CustId
		LEFT JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = cd.UplineId
		INNER JOIN dbo.ProblemAccountReason pr WITH (NOLOCK) ON pr.ReasonID = cd.ReasonId
	WHERE RowNumber BETWEEN @RowStart AND @RowEnd 	
	ORDER BY cd.CustId, cd.CreateDate DESC

	DROP TABLE #CustDetailList
	DROP TABLE #CustList
	DROP TABLE #Result
END
GO
