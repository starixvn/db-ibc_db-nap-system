/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_SiteSel] 
	 @PageSize		INT = 50
	,@PageIndex		INT = 1
	,@TotalItems	INT = 0 OUTPUT
	,@IsTest		BIT = 0
AS
/*
	Created: 20190815@Eden
	Task : Get Bet Restriction Site 
	DB: DBACC/bodb02
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]
	- 20230613@Luke: Option to apply Seize Bet if reach risk balance [Redmine: #187771]

	Example: 
	DECLARE @TotalItems	INT 
	EXEC NAP_BetRestriction_SiteSel 
		@PageSize	= 10,
		@PageIndex	= 1,
		@TotalItems = @TotalItems OUTPUT,
		@IsTest = 1
	SELECT @TotalItems
	
	
	*/
BEGIN
	DECLARE @RowCount int, @RowStart int, @RowEnd int
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	SELECT SportType,IsShowData 
	INTO  #Setting
	FROM  dbo.f_BetRestrictionSettingSel('BetRestriction_Site',@IsTest)

	CREATE TABLE #BetRestriction_Site(
		[site] nvarchar(50),
		SiteID int,
		SportType smallint,
		LiveBetAccept smallint,
		SeizeBetTicket tinyint,
		FollowAccountID int,
		[FollowAccount] nvarchar(50),
		AccumulateBalance BIT,
		RowNumber INT PRIMARY KEY CLUSTERED
	)

	INSERT INTO #BetRestriction_Site(
		[site],
		SiteID,
		SportType,
		LiveBetAccept,
		SeizeBetTicket,
		FollowAccountID,
		FollowAccount,
		AccumulateBalance,
		RowNumber
	)

	SELECT s.[site],
		   bs.SiteID,
		   bs.SportType,
		   bs.LiveBetAccept, 
		   bs.SeizeBetTicket, 
		   bs.FollowAccount AS FollowAccountID,
		   ci.username AS FollowAccount,
		   CASE WHEN ISNULL(bs.AccumulateBalance,0) = 0 THEN 0 ELSE 1 END AS AccumulateBalance,
		   ROW_NUMBER() OVER (ORDER BY [Site]) AS RowNumber
	FROM BetRestriction_Site bs WITH(NOLOCK)
		 INNER JOIN [Site] s WITH(NOLOCK) ON bs.SiteID = s.siteid
		 LEFT JOIN CustInfo ci WITH(NOLOCK) ON ci.custid = bs.FollowAccount
		 INNER JOIN #Setting st WITH(NOLOCK) ON bs.SportType = st.SportType AND st.IsShowData = 1
	
	SELECT @TotalItems = COUNT(1)  
	FROM #BetRestriction_Site

	SELECT * 
	FROM #BetRestriction_Site
	WHERE RowNumber BETWEEN @rowstart AND @rowend 		
END
GO


