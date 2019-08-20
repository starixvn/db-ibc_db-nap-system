/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CustomerSel] (
	 @Username		NVARCHAR(50) = NULL
	,@RoleID		TINYINT = NULL
	,@Status		VARCHAR(10) = NULL
	,@SiteID		INT = NULL
	,@CurrencyID	TINYINT = NULL
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
		@CurrencyID = 0,
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
		   CASE WHEN  ISNULL(c.site,'') <> 'CN88' AND ISNULL(s.isLicensee,AgentSite.isLicensee) = 0 AND ci.Closed = 0 AND ISNULL(ci.reject, 0) = 0 THEN 'Active'
				WHEN  ISNULL(c.site,'') <> 'CN88' AND ISNULL(s.isLicensee,AgentSite.isLicensee) = 0 AND ci.Closed = 0 AND ISNULL(ci.reject, 0) = 1 THEN 'Suspended'
				WHEN  ISNULL(c.site,'') <> 'CN88' AND ISNULL(s.isLicensee,AgentSite.isLicensee) = 0 AND ci.Closed = 1 THEN 'Close'
				WHEN  c.site = 'CN88' AND s.isLicensee = 0 AND cn88Stat.CustStatus = 1 THEN 'Active'
				WHEN  c.site = 'CN88' AND s.isLicensee = 0 AND cn88Stat.CustStatus = 2 THEN 'View Only'
				WHEN  c.site = 'CN88' AND s.isLicensee = 0 AND cn88Stat.CustStatus = 3 THEN 'Suspended'
				WHEN  c.site = 'CN88' AND s.isLicensee = 0 AND cn88Stat.CustStatus = 4 THEN 'Inactive'
				ELSE 'N/A'
		   END AS [Status],
		   COALESCE(NULLIF(c.[site],''),agent.site,'') AS Site,
		   ISNULL(s.siteid,AgentSite.siteid) as SiteID,
		   bc.LiveBetAccept, 
		   bc.SeizeBetTicket, 
		   e.Currency,
		   bc.MaxBet, 
		   bc.MaxPerMatch, 
		   CASE WHEN cp.CustId IS NOT NULL THEN 'YES' ELSE 'NO' END AS ProblemAccount,
		   bc.FollowAccount AS FollowAccountID,
		   rm.username AS [FollowAccount]
	INTO #BetRestriction_Customer
	FROM BetRestriction_Customer bc WITH(NOLOCK)
		 INNER JOIN custInfo ci WITH(NOLOCK) ON bc.CustID = ci.custid
		 INNER JOIN Customer c WITH(NOLOCK) ON bc.custid = c.custid
		 INNER JOIN exchange e WITH(NOLOCK) ON ci.currency = e.exchangeid
		 LEFT JOIN custAccount ca WITH(NOLOCK) ON bc.CustID = ca.CustID
		 LEFT JOIN custAccount head WITH(NOLOCK) ON ca.groupID = head.groupID AND head.IsGroupHeadLine = 1
		 LEFT JOIN custInfo headname WITH(NOLOCK) ON headname.custid = head.custid
		 LEFT JOIN CS_ProblemAccount cp  WITH(NOLOCK) ON cp.CustId = bc.CustID  
		 LEFT JOIN Site s WITH(NOLOCK) ON s.site = c.site
		 LEFT JOIN Customer Agent WITH(NOLOCK) ON agent.custid = ci.recommend
		 LEFT JOIN Site AgentSite WITH(NOLOCK) ON AgentSite.site = agent.site
		 OUTER APPLY dbo.f_CS_GetCustomerStatus (bc.custid) cn88Stat
		 LEFT JOIN custInfo rm WITH(NOLOCK) ON rm.custid = bc.FollowAccount
		 INNER JOIN #Setting st WITH(NOLOCK) ON bc.SportType = st.SportType AND st.IsShowData = 1
	WHERE ci.username = CASE WHEN ISNULL(@Username,'') <> ''  THEN @Username  ELSE ci.username END
		  AND ci.currency = CASE WHEN ISNULL(@CurrencyID,0) <> 0 THEN @CurrencyID ELSE ci.currency END
		  AND ci.roleid = CASE WHEN @RoleID IS NOT NULL THEN @RoleID ELSE ci.roleid END
	
	SELECT *, ROW_NUMBER() OVER (ORDER BY Headline, Account) AS RowNumber
	INTO #BetRestriction_Customer2
	FROM #BetRestriction_Customer tmp
	WHERE tmp.SiteID = CASE WHEN ISNULL(@SiteID,0) <> 0 THEN @SiteID ELSE tmp.SiteID END 
		AND tmp.Status = CASE WHEN ISNULL(@Status,'All') <> 'All' THEN @Status ELSE tmp.Status END 
	
	SELECT @TotalItems = COUNT(1) 
	FROM #BetRestriction_Customer2

	SELECT * 
	FROM #BetRestriction_Customer2
	WHERE RowNumber BETWEEN @rowstart AND @rowend 		
END
GO


