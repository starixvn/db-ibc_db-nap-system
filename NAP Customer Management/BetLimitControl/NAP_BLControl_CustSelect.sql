/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
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
	@ErrorMsg VARCHAR(200) = '' OUTPUT
AS
/*
	Created: 20200528@Eden
	Task : Bet Limit Control - select CustSetting Detail 
	DB: DBACC-bodb02
	Original:

	Revisions:  
	- 20200528@Eden: Create New SP  [RedmineID: #132736]
	- 20210513@Eden: BLC by pecentage of Match Max Bet [RedmineID: #154984]
	- 20250228@Logan: Enhance SP search by 1 Username [RedmineID: #218264]

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
	EXEC DBCUST.NAP_UserControl.dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey='CustomerManagement',
		@FunctionKey='BetLimitControl',
		@Policy=1,
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		RETURN

	DECLARE @HasCN88_Permission BIT = 0,
		@HasCredit_Permission BIT = 0,
		@HasLicensee_Permission BIT = 0

	--EXEC DBCUST.NAP_UserControl.dbo.NAP_User_CheckPermission 
	--		@UserId=@userid,
	--		@SiteKey='CustomerManagement',
	--		@FunctionKey='BLC_CN88Site',
	--		@Policy=1,
	--		@ErrCode=@ErrorCode OUTPUT

	--IF @ErrorCode = 0 SET @HasCN88_Permission = 1

	SET @ErrorCode = 0
	EXEC DBCUST.NAP_UserControl.dbo.NAP_User_CheckPermission 
			@UserId=@userid,
			@SiteKey='CustomerManagement',
			@FunctionKey='BLC_Credit',
			@Policy=1,
			@ErrCode=@ErrorCode OUTPUT

	IF @ErrorCode = 0 SET @HasCredit_Permission = 1

	SET @ErrorCode = 0
	EXEC DBCUST.NAP_UserControl.dbo.NAP_User_CheckPermission 
			@UserId=@userid,
			@SiteKey='CustomerManagement',
			@FunctionKey='BLC_LicenseeSite',
			@Policy=1,
			@ErrCode=@ErrorCode OUTPUT

	IF @ErrorCode = 0 SET @HasLicensee_Permission = 1

	DECLARE @RowCount int, @RowStart int, @RowEnd int

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	SELECT c.CustID,
       c.username,
       VIP = CAST(CASE
                       WHEN vip.CustID IS NOT NULL THEN 1
                       ELSE 0 END AS BIT),
       [Level] = CASE
                      WHEN c.roleid = 1 THEN 'Member'
                      WHEN c.roleid = 2 THEN 'Agent'
                      WHEN c.roleid = 3 THEN 'Master'
                      WHEN c.roleid = 4 THEN 'Super'
                      ELSE 'N/A' END,
       e.Currency,
       ISNULL(c.Site, '') AS Site,
       a.BetLimitType,
       a.BetLimitTypeID,
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
	   ROW_NUMBER() OVER (ORDER BY c.Username, a.BetLimitType) AS RowNumber
	INTO #Cust
  FROM BetLimitControlType a WITH (NOLOCK)
       CROSS APPLY (   SELECT TOP 1 custid,
                                    username,
                                    site,
                                    currency,
                                    roleid,
                                    srecommend,
                                    mrecommend,
                                    recommend
                         FROM customer cu WITH (NOLOCK)
                              CROSS APPLY ( SELECT TOP 1 SiteID , isLicensee FROM Site WITH (NOLOCK) WHERE site  = cu.site) s
                        WHERE username = @Username
						  AND cu.roleid   = CASE                         WHEN ISNULL(@LevelID, 0) <> 0 THEN @LevelID
                         ELSE cu.roleid END
                          AND s.SiteID = CASE WHEN @SiteID <> 0 THEN @SiteID ELSE s.SiteID END
						   AND cu.Currency = CASE
                         WHEN ISNULL(@Currency, 0) <> 0 THEN @Currency
                         ELSE cu.Currency END 	
                          AND (   (   s.isLicensee            = 1 AND   @HasLicensee_Permission = 1)
                             OR   (   s.isLicensee              = 0  AND   @HasCredit_Permission     = 1))) c
       INNER JOIN exchange e WITH (NOLOCK) ON c.currency = e.exchangeid
       LEFT JOIN dbo.Dep_CustVIP vip WITH (NOLOCK)
         ON c.CustID = vip.CustID
       CROSS APPLY (   SELECT Mode,
                              MaxBet,
                              MaxPerMatch
                         FROM BetLimitControlCustSetting WITH (NOLOCK)
                        WHERE custid         = c.custid
                          AND BetLimitTypeID = a.BetLimitTypeID
                          AND BetLimitTypeID = CASE
                                                    WHEN ISNULL(@BetLimitTypeID, 0) <> 0 THEN @BetLimitTypeID
                                                    ELSE BetLimitTypeID END) bc
       OUTER APPLY (   SELECT TOP 1 Mode,
                              MaxBet,
                              MaxPerMatch
                         FROM BetLimitControlCustSetting WITH (NOLOCK)
                        WHERE custid         = c.srecommend
                          AND BetLimitTypeID = a.BetLimitTypeID
                          AND c.srecommend   <> c.custid) spbc
       OUTER APPLY (   SELECT TOP 1 Mode, MaxBet, MaxPerMatch
                         FROM BetLimitControlCustSetting WITH (NOLOCK)
                        WHERE custid         = c.mrecommend
                          AND BetLimitTypeID = a.BetLimitTypeID
                          AND c.mrecommend   <> c.custid) mtbc
       OUTER APPLY (   SELECT TOP 1 Mode,MaxBet,MaxPerMatch FROM BetLimitControlCustSetting WITH (NOLOCK)
                        WHERE custid         = c.recommend AND BetLimitTypeID = a.BetLimitTypeID AND c.recommend    <> c.custid) agbc; 	
	
	CREATE CLUSTERED INDEX IX_BLTmpCust_Rownum ON #Cust(RowNumber)  
	
	SELECT TOP 1 @TotalItems = RowNumber
	FROM #Cust
	ORDER BY RowNumber DESC
	
	SELECT * 
	FROM #Cust
	WHERE RowNumber BETWEEN @rowstart AND @rowend 	
END
