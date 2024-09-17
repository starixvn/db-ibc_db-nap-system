/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_CustSelect] 
	@LevelID TINYINT = NULL,
	@Currency INT = NULL,
	@SiteID INT = NULL,
	@BetLimitTypeID INT = NULL,
	@Username VARCHAR(30) = NULL,
	@PageSize INT = 50,
	@PageIndex	INT = 1,
	@TotalItems	INT = 0 OUTPUT,
	@Permission	VARCHAR(20) = '1,2'

AS
/*
	Created: 20200528@Eden
	Task : Bet Limit Control - select CustSetting Detail 
	DB: DBACC-bodb02
	Original:

	Revisions:  
	- 20200528@Eden: Create New SP  [RedmineID: #132736]
	- 20210513@Eden: BLC by pecentage of Match Max Bet [RedmineID: #154984]
	- 20240725@Tacy: Remove linked-server/cross-db on NAP_UserControl [redmineID: #208402]

	Parameter explanation:
		- @LevelID : 1- Member, 2 - Agent, 3-Masrer, 4 - Super, 0 - all
		
		- @Permission:	1 ~ Credit sites
						2 ~ Licensee sites

	Example: 
	DECLARE @TotalItems	INT 
	EXEC NAP_BLControl_CustSelect 
		@LevelID = 0,
		@Currency = 0,
		@SiteID = 1,
		@Username = '',
		@BetLimitTypeID = 0,
		@PageSize	= 50,
		@PageIndex	= 1,
		@TotalItems = @TotalItems OUTPUT

		SELECT @TotalItems

	*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @RowCount int, @RowStart int, @RowEnd int

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	SELECT bc.CustID,
		c.username,
		VIP = CAST(CASE WHEN vip.CustID IS NOT NULL THEN 1 ELSE 0 END  AS BIT),
		[Level] = CASE WHEN c.roleid = 1 THEN 'Member'
						WHEN c.roleid = 2 THEN 'Agent'
						WHEN c.roleid = 3 THEN 'Master'
						WHEN c.roleid = 4 THEN 'Super'
						ELSE 'N/A'
				END,
		e.Currency,
		COALESCE(s.Site,ag.site,'') AS Site,
		b.BetLimitType,
		b.BetLimitTypeID,
		bc.Mode,
		bc.MaxBet,
		bc.MaxPerMatch,
		agbc.Mode AS AgentMode,
		agbc.MaxBet AS Agent_MaxBet,
		agbc.MaxPerMatch AS Agent_MaxPerMatch,
		mtbc.Mode AS MasterMode,
		mtbc.MaxBet AS Master_MaxBet,
		mtbc.MaxPerMatch AS Master_MaxPerMatch,
		spbc.Mode AS SuperMode,
		spbc.MaxBet AS Super_MaxBet,
		spbc.MaxPerMatch AS Super_MaxPerMatch,
		ROW_NUMBER() OVER (ORDER BY c.Username,b.BetLimitType) AS RowNumber
	INTO #Cust
	FROM BetLimitControlCustSetting bc WITH(NOLOCK)
		INNER JOIN customer c WITH(NOLOCK) on bc.CustID = c.CustID
		INNER JOIN exchange e WITH(NOLOCK) ON c.currency = e.exchangeid
		INNER JOIN BetLimitControlType b WITH(NOLOCK) ON bc.BetLimitTypeID = b.BetLimitTypeID
		LEFT JOIN dbo.Dep_CustVIP vip WITH(NOLOCK) ON bc.CustID = vip.CustID
		LEFT JOIN Customer Ag WITH(NOLOCK) ON ag.custid = c.recommend
		LEFT JOIN BetLimitControlCustSetting agbc WITH(NOLOCK) ON agbc.CustID = ag.custid AND agbc.BetLimitTypeID = bc.BetLimitTypeID AND agbc.CustID <> bc.CustID
		LEFT JOIN Customer mt WITH(NOLOCK) ON mt.custid = c.mrecommend
		LEFT JOIN BetLimitControlCustSetting mtbc WITH(NOLOCK) ON mtbc.CustID = mt.custid AND mtbc.BetLimitTypeID = bc.BetLimitTypeID AND mtbc.CustID <> bc.CustID
		LEFT JOIN Customer sp WITH(NOLOCK) ON sp.custid = c.srecommend
		LEFT JOIN BetLimitControlCustSetting spbc WITH(NOLOCK) ON spbc.CustID = sp.custid AND spbc.BetLimitTypeID = bc.BetLimitTypeID AND spbc.CustID <> bc.CustID
		LEFT JOIN Site s WITH(NOLOCK) ON s.site = c.site AND s.site <> ''
		LEFT JOIN Site agSite WITH(NOLOCK) ON agSite.site = ag.site	
	WHERE c.username = CASE WHEN ISNULL(@Username,'') <> ''  THEN @Username  ELSE c.username END
		  AND c.roleid = CASE WHEN ISNULL(@LevelID,0) <> 0 THEN @LevelID ELSE c.roleid END
		  AND ISNULL(s.SiteID,agSite.siteid) = CASE WHEN ISNULL(@SiteID,0) <> 0 THEN @SiteID ELSE ISNULL(s.SiteID,agSite.siteid) END 
		  AND c.Currency = CASE WHEN ISNULL(@Currency,0) <> 0 THEN @Currency ELSE c.Currency END
		  AND bc.BetLimitTypeID = CASE WHEN ISNULL(@BetLimitTypeID,0) <> 0 THEN @BetLimitTypeID ELSE bc.BetLimitTypeID END
		  AND (( COALESCE(s.isLicensee,agSite.isLicensee) = 1 AND ',' + @Permission + ',' LIKE '%,2,%' ) 
				OR (COALESCE(s.isLicensee,agSite.isLicensee) = 0 AND ',' + @Permission + ',' LIKE '%,1,%' ))
		  AND COALESCE(s.Site,ag.site,'') <> 'CN88'
		
	CREATE CLUSTERED INDEX IX_BLTmpCust_Rownum ON #Cust(RowNumber)  

	SELECT TOP 1 @TotalItems = RowNumber
	FROM #Cust
	ORDER BY RowNumber DESC

	SELECT * 
	FROM #Cust
	WHERE RowNumber BETWEEN @rowstart AND @rowend 	
END
GO


