/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CustomerSel] (
	 @Username		NVARCHAR(50) = NULL
	,@SportType 	INT = 1
	,@RoleID		TINYINT = NULL
	,@Status		VARCHAR(10) = NULL
	,@SiteID		INT = NULL
	,@CurrencyIDs	VARCHAR(MAX) = NULL
	,@PageSize		INT = 50
	,@PageIndex		INT = 1
	,@TotalItems	INT = 0 OUTPUT
	,@IsTest		BIT = 0
) 
AS

/*
	Created: 20190815@Eden
	Task : Get Bet Restriction Customer 
	DB: DBACC/bodb02
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]
	- 20210617@Tina: Lock account & indirect close account [redmine: #148600]
	- 20210802@Johnson: add @sporttype to support bet restriction for basketball [redmine:#158229]
	- 20230303@Helios: Remove Column ProblemAccount AND Get NewColumn LeagueGroupID [redmine:#183663]
	- 20230613@Luke: Option to apply Seize Bet if reach risk balance [Redmine: #187771]
	- 20250327@Winfred: [NAP CM] Customer - Bet Restriction - E-Sports [Redmine: #221607]
	- 20250428@Logan: Basketball - AddcTicket Stake [redmine:#223442]

	Parameter Definition
		@RoleID = : 1- Member, 2 - Agent, 3-Masrer, 4 - Super
		@Status = : All, Active, View Only, Suspended, Inactive

	Example: 
	DECLARE @TotalItems	INT 
	EXEC NAP_BetRestriction_CustomerSel 
		--@Username  = 'supertest01',
		--@RoleID    = 4,
		@Status	= 'All',
		@SiteID		= 0,
		@CurrencyIDs = '1,2',
		@PageSize	= 50,
		@PageIndex	= 1,
		@TotalItems = @TotalItems OUTPUT,
		@IsTest= 0
	SELECT @TotalItems
	
	*/
BEGIN
	DECLARE @RowCount int, @RowStart int, @RowEnd int

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	SELECT SportType,IsShowData 
	INTO  #Setting
	FROM  dbo.f_BetRestrictionSettingSel('BetRestriction_Customer',@IsTest)
	WHERE sporttype= @sporttype
	
	SELECT bc.CustID,
		   bc.SportType,
		   headname.username AS Headline,
		   ci.username as Account, 
		   ci.roleid,
		   [Level] = CASE WHEN ci.roleid = 1 THEN 'Member'
						  WHEN ci.roleid = 2 THEN 'Agent'
						  WHEN ci.roleid = 3 THEN 'Master'
						  WHEN ci.roleid = 4 THEN 'Super'
						  ELSE 'N/A'
					END,
		   CASE WHEN  cps.Closed = 0 AND ISNULL(cps.reject, 0) = 0 THEN 'Open'
				WHEN  cps.Closed = 0 AND ISNULL(cps.reject, 0) = 1 THEN 'Suspended'
				WHEN  cps.Closed = 1 THEN 'Closed'
				ELSE 'N/A'
		   END AS [Status],
		   ISNULL(c.[site],'') AS Site,
		   s.siteid as SiteID,
		   bc.LiveBetAccept, 
		   bc.SeizeBetTicket, 
		   e.Currency,
		   bc.MaxBet, 
		   bc.MaxPerMatch,
		   --CASE WHEN cp.CustId IS NOT NULL THEN 'YES' ELSE 'NO' END AS ProblemAccount,          -- Change By [redmine:#183663]
		   bc.FollowAccount AS FollowAccountID,
		   CASE WHEN ISNULL(bc.AccumulateBalance,0) = 0 THEN 0 ELSE 1 END AS AccumulateBalance,
		   rm.username AS [FollowAccount],
		   CASE WHEN bc.LeagueGroupID IS NULL THEN '' ELSE bc.LeagueGroupID END AS LeagueGroupID,    -- Change By [redmine:#183663]
		   bc.LeastStake	-- Add New Column #223442
	INTO #BetRestriction_Customer
	FROM BetRestriction_Customer bc WITH(NOLOCK)
		 INNER JOIN custInfo ci WITH(NOLOCK) ON bc.CustID = ci.custid
		 INNER JOIN Customer c WITH(NOLOCK) ON bc.custid = c.custid
		 INNER JOIN exchange e WITH(NOLOCK) ON ci.currency = e.exchangeid
		 OUTER APPLY (	SELECT ca1.groupID 
						FROM custAccount ca1 WITH(NOLOCK)
						WHERE c.CustID = ca1.CustID  AND c.site <> 'CN88' 
						UNION ALL 
						SELECT ca2.groupID 
						FROM custAccount ca2 WITH(NOLOCK) 
						WHERE c.srecommend = ca2.CustID  AND c.site = 'CN88' 
					) ca
		 LEFT JOIN custAccount head WITH(NOLOCK) ON ca.groupID = head.groupID AND head.IsGroupHeadLine = 1
		 LEFT JOIN custInfo headname WITH(NOLOCK) ON headname.custid = head.custid
		 --LEFT JOIN CS_ProblemAccount cp  WITH(NOLOCK) ON cp.CustId = bc.CustID    -- Change By [redmine:#183663]
		 LEFT JOIN Customer Agent WITH(NOLOCK) ON agent.custid = ci.recommend
		 LEFT JOIN custInfo rm WITH(NOLOCK) ON rm.custid = bc.FollowAccount
		 LEFT JOIN Site s WITH(NOLOCK) ON s.site = c.site
		 INNER JOIN #Setting st WITH(NOLOCK) ON bc.SportType = st.SportType AND st.IsShowData = 1
		 OUTER APPLY  (SELECT CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS closed
										, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS reject
									FROM dbo.CustProductStatus  WITH(NOLOCK)
									WHERE CustID = ci.custid
					  ) AS cps
	WHERE ci.username = CASE WHEN ISNULL(@Username,'') <> ''  THEN @Username  ELSE ci.username END
		  AND ci.roleid = CASE WHEN @RoleID IS NOT NULL THEN @RoleID ELSE ci.roleid END
		  AND ci.currency IN (SELECT val FROM dbo.f_SplitString(@CurrencyIDs,','))
	OPTION (MAXRECURSION 0)
	
	CREATE TABLE #BetRestriction_Customer2(
		CustID INT,
		SportType smallint,
		Headline nvarchar(50),
		Account nvarchar(50),
		roleid tinyint,
		[Level] varchar(7),
		[Status] VARCHAR(20),
		[Site] nvarchar(50),
		SiteID int,
		LiveBetAccept smallint,
		SeizeBetTicket tinyint,
		Currency nvarchar(50),
		MaxBet money,
		MaxPerMatch money,
		--ProblemAccount VARCHAR(3), -- Change By [redmine:#183663]
		FollowAccountID int,
		[FollowAccount] nvarchar(50),
		AccumulateBalance BIT,
		RowNumber INT PRIMARY KEY CLUSTERED,
	    LeagueGroupID varchar(4000), -- Change By [redmine:#183663]
		LeastStake MONEY	-- Add New Column #223442
	)
	
	INSERT INTO #BetRestriction_Customer2(
		CustID,
		SportType,
		Headline,
		Account,
		roleid,
		[Level],
		[Status],
		Site,
		SiteID,
		LiveBetAccept,
		SeizeBetTicket,
		Currency,
		MaxBet,
		MaxPerMatch,
		--ProblemAccount, -- Change By [redmine:#183663]
		FollowAccountID,
		[FollowAccount],
		AccumulateBalance,
		RowNumber,
		LeagueGroupID, -- Change By [redmine:#183663]
		LeastStake	-- Add New Column #223442
	)
	SELECT CustID,
		SportType,
		Headline,
		Account,
		roleid,
		[Level],
		[Status],
		Site,
		SiteID,
		LiveBetAccept,
		SeizeBetTicket,
		Currency,
		MaxBet,
		MaxPerMatch,
		--ProblemAccount, -- Change By [redmine:#183663]
		FollowAccountID,
		[FollowAccount], 
		AccumulateBalance,
		ROW_NUMBER() OVER (ORDER BY Headline, Account) AS RowNumber,
		LeagueGroupID, -- Change By [redmine:#183663]
		LeastStake	-- Add New Column #223442
	FROM #BetRestriction_Customer tmp
	WHERE tmp.SiteID = CASE WHEN ISNULL(@SiteID,0) <> 0 THEN @SiteID ELSE tmp.SiteID END 
		AND tmp.Status = CASE WHEN ISNULL(@Status,'All') <> 'All' THEN @Status ELSE tmp.Status END 
	
	SELECT @TotalItems = COUNT(1) 
	FROM #BetRestriction_Customer2

	SELECT * 
	FROM #BetRestriction_Customer2
	WHERE RowNumber BETWEEN @rowstart AND @rowend 
	
 DROP TABLE #Setting
 DROP TABLE #BetRestriction_Customer
 DROP TABLE #BetRestriction_Customer2

END
GO


