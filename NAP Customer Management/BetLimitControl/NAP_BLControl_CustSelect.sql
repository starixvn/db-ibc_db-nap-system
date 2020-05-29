/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_CustSelect] 
	@LevelID TINYINT = NULL,
	@Currency INT = NULL,
	@SiteID INT = NULL,
	@BetLimitTypeID INT = NULL,
	@Username VARCHAR(30) = NULL,
	@UserId INT = 0,
	@PageSize INT = 50,
	@PageIndex	INT = 1,
	@TotalItems	INT = 0 OUTPUT,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20200528@Eden
	Task : Bet Limit Control - select CustSetting Detail 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200528@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:
		- @LevelID : 1- Member, 2 - Agent, 3-Masrer, 4 - Super, 0 - all

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
		@TotalItems = @TotalItems OUTPUT,
		@UserId = 8

		SELECT @TotalItems

	*/
BEGIN
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey='CustomerManagement',
		@FunctionKey='BetLimitTypeControl',
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		RETURN

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
		sp.Site,
		b.BetLimitType,
		b.BetLimitTypeID,
		bc.MaxBet,
		bc.MaxPerMatch,
		agbc.MaxBet AS Agent_MaxBet,
		agbc.MaxPerMatch AS Agent_MaxPerMatch,
		mtbc.MaxBet AS Master_MaxBet,
		mtbc.MaxPerMatch AS Master_MaxPerMatch,
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
		LEFT JOIN Site spSite WITH(NOLOCK) ON spSite.site = sp.site
	WHERE c.username = CASE WHEN ISNULL(@Username,'') <> ''  THEN @Username  ELSE c.username END
		  AND c.roleid = CASE WHEN ISNULL(@LevelID,0) <> 0 THEN @LevelID ELSE c.roleid END
		  AND spSite.SiteID = CASE WHEN ISNULL(@SiteID,0) <> 0 THEN @SiteID ELSE spSite.SiteID END 
		  AND c.Currency = CASE WHEN ISNULL(@Currency,0) <> 0 THEN @Currency ELSE c.Currency END
		  AND bc.BetLimitTypeID = CASE WHEN ISNULL(@BetLimitTypeID,0) <> 0 THEN @BetLimitTypeID ELSE bc.BetLimitTypeID END

	CREATE NONCLUSTERED INDEX IX_BLTmpCust_Rownum ON #Cust(RowNumber)  

	SELECT @TotalItems = COUNT(1) 
	FROM #Cust

	SELECT * 
	FROM #Cust
	WHERE RowNumber BETWEEN @rowstart AND @rowend 	
END
GO


