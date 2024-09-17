/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_TypeDelete] 
	@BetLimitTypeID INT,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(100) = '' OUTPUT,
	@UserId INT = 0 ,
	@IP	VARCHAR(15) = '' 
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - Remove Type 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
		- 20200525@Eden: Create New SP  [RedmineID: #132736]
		- 20200818@Eden: Auto Update Bet Limit Control [RedmineID: #139701]
		- 20220413@Johnson: BLC implement setting by League Group [redmine:#156808]
		- 20240725@Tacy: Remove linked-server/cross-db on NAP_UserControl [redmineID: #208402]
	Parameter explanation:
	- @LiveIndicator : 0 : NonLive , 1: Live , 2 : Both, 3 : All
	- @ErrorCode: 
		1: The Bet Limit Type does not exist.

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(100) = '' 
	EXEC NAP_BLControl_TypeDelete 
		@BetLimitTypeID = 1,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31752

	SET @StartRun = GETDATE()

	IF NOT EXISTS( SELECT TOP 1 1 FROM BetLimitControlType t WITH(NOLOCK) WHERE t.BetLimitTypeID = @BetLimitTypeID )
	BEGIN
		SELECT @ErrorCode = 1 ,
			@ErrorMsg = 'The Bet Limit Type does not exist.'

		RETURN
	END

	CREATE TABLE #OLdbetLimitTypeTbl
	(
		BetLimitTypeID INT,
		BetLimitType VARCHAR(50),
		BeginTime TIME,
		EndTime TIME,
		LiveIndicator TINYINT,
		RestrictVIP BIT,
		ProductList VARCHAR(200),
		SportTypeList VARCHAR(MAX),		
		BetTypeList VARCHAR(MAX),
		LeagueGroupList VARCHAR(MAX),
		LeagueList VARCHAR(MAX),
		ExcludedLeagueGroupList VARCHAR(MAX),
		IsAllProduct BIT,
		IsAllSporttype BIT,
		IsAllBettype BIT,
		IsAllLeague BIT
	)
	
	INSERT INTO #OLdbetLimitTypeTbl(
		 BetLimitTypeID
		,BetLimitType  
		,BeginTime     
		,EndTime       
		,LiveIndicator 
		,RestrictVIP   
		,ProductList   
		,SportTypeList 
		,BetTypeList   
		,LeagueGroupList
		,ExcludedLeagueGroupList
		,LeagueList  			
		,IsAllProduct  
		,IsAllSporttype
		,IsAllBettype  
		,IsAllLeague   
	)
	EXEC NAP_BLControl_TypeSelect 
		@ProductID = 0,
		@Sporttype = 0,
		@Bettype = 0,
		@LiveIndicator = 3,
		@BetLimitTypeID = @BetLimitTypeID

	DECLARE @BetLimitType VARCHAR(50),
		@BeginTime TIME,
		@EndTime TIME,
		@LiveIndicator TINYINT,
		@RestrictVIP BIT,
		@ProductList VARCHAR(200),
		@SportTypeList VARCHAR(MAX),
		@BetTypeList VARCHAR(MAX),
		@LeagueList VARCHAR(MAX),
		@LeagueGroupList VARCHAR(MAX),
		@ExcludedLeagueGroupList VARCHAR(MAX)

	SELECT @BetLimitType  		= BetLimitType  
		,@BeginTime     		= BeginTime     
		,@EndTime       		= EndTime       
		,@LiveIndicator 		= LiveIndicator 
		,@RestrictVIP   		= RestrictVIP   
		,@ProductList   		= CASE WHEN IsAllProduct = 1 THEN '0' ELSE ProductList  END
		,@SportTypeList 		= CASE WHEN IsAllSporttype = 1 THEN '0' ELSE SportTypeList  END  
		,@BetTypeList   		= CASE WHEN IsAllBettype = 1 THEN '0' ELSE BetTypeList  END     
		,@LeagueList    		= CASE WHEN IsAllLeague = 1 THEN '' ELSE LeagueList  END      
		,@LeagueGroupList 		= LeagueGroupList
		,@ExcludedLeagueGroupList = ExcludedLeagueGroupList
	FROM #OLdbetLimitTypeTbl

	DELETE 
	FROM BetLimitControlTypeDetail WITH(ROWLOCK,UPDLOCK)
	WHERE BetLimitTypeID = @BetLimitTypeID

	DELETE 
	FROM BetLimitControlType WITH(ROWLOCK,UPDLOCK)
	WHERE BetLimitTypeID = @BetLimitTypeID

	DELETE 
	FROM BetLimitControlDefaultSetting WITH(ROWLOCK,UPDLOCK)
	WHERE BetLimitTypeID = @BetLimitTypeID

	--Delete all setting on BetLimitControlCustSetting
	EXEC [Acc_CustSetting_11]
		@CustID = 0,
		@BetLimitTypeID	= @BetLimitTypeID

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)


	DECLARE @LogData VARCHAR(500),@NewLogData VARCHAR(500)
	SELECT  @LogData = '<R '
						+ 'Type="'+ coalesce(cast(@BetLimitType as varchar(50)),space(1)) + '" ' 
						+ 'Product="'+ coalesce(cast(@ProductList as varchar(50)),space(1)) + '" ' 
						+ 'Sport="'+ coalesce(cast(@SporttypeList as varchar(50)),space(1)) + '" ' 
						+ 'BetType="'+ coalesce(cast(@BettypeList as varchar(50)),space(1)) + '" '
						+ 'LiveIndicator="'+ coalesce(cast(@LiveIndicator as varchar(50)),space(1)) + '" '  
						+ 'LeagueID="'+ coalesce(cast(@LeagueList as varchar(50)),space(1)) + '" ' 
						+ 'LeagueGroupList="'+ coalesce(cast(@LeagueGroupList as varchar(MAX)),space(1)) + '" ' 
						+ 'ExcludedLeagueGroupList="'+ coalesce(cast(@ExcludedLeagueGroupList as varchar(MAX)),space(1)) + '" ' 
						+ 'SpecificTime="'+ coalesce(cast(CASE WHEN @BeginTime IS NOT NULL THEN 1 ELSE 0 END as varchar(50)),space(1)) + '" ' 
						+ 'FromTime="'+ coalesce(cast(@BeginTime as varchar(50)),space(1)) + '" ' 
						+ 'ToTime="'+ coalesce(cast(@EndTime as varchar(50)),space(1)) + '" ' 
						+ 'RestrictVIP="'+ coalesce(cast(@RestrictVIP as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />'

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserId				= @UserId,
		@ActionId			= @ActionID,
		@TrackingValue		= @LogData,
		@Duration			= @Duration
END
GO


