/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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

	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey='CustomerManagement',
		@FunctionKey='BetLimitTypeControl',
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		RETURN

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
		LeagueList VARCHAR(MAX),
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
		@BetLimitTypeID = @BetLimitTypeID,
		@UserId = @UserId

	DECLARE @BetLimitType VARCHAR(50),
		@BeginTime TIME,
		@EndTime TIME,
		@LiveIndicator TINYINT,
		@RestrictVIP BIT,
		@ProductList VARCHAR(200),
		@SportTypeList VARCHAR(MAX),
		@BetTypeList VARCHAR(MAX),
		@LeagueList VARCHAR(MAX)

	SELECT @BetLimitType  		= BetLimitType  
		,@BeginTime     		= BeginTime     
		,@EndTime       		= EndTime       
		,@LiveIndicator 		= LiveIndicator 
		,@RestrictVIP   		= RestrictVIP   
		,@ProductList   		= CASE WHEN IsAllProduct = 1 THEN '0' ELSE ProductList  END
		,@SportTypeList 		= CASE WHEN IsAllSporttype = 1 THEN '0' ELSE SportTypeList  END  
		,@BetTypeList   		= CASE WHEN IsAllBettype = 1 THEN '0' ELSE BetTypeList  END     
		,@LeagueList    		= CASE WHEN IsAllLeague = 1 THEN '' ELSE LeagueList  END      
	FROM #OLdbetLimitTypeTbl

	DELETE 
	FROM BetLimitControlTypeDetail WITH(ROWLOCK,UPDLOCK)
	WHERE BetLimitTypeID = @BetLimitTypeID

	DELETE 
	FROM BetLimitControlType WITH(ROWLOCK,UPDLOCK)
	WHERE BetLimitTypeID = @BetLimitTypeID

	SELECT CustID
	INTO #TempCust
	FROM BetLimitControlCustSetting WITH(NOLOCK)
	WHERE BetLimitTypeID = @BetLimitTypeID

	WHILE 1 = 1
	BEGIN
		DELETE TOP (1000) bc
		FROM BetLimitControlCustSetting bc WITH(ROWLOCK)
			INNER JOIN #TempCust t ON t.CustID = bc.CustID 
		WHERE bc.BetLimitTypeID = @BetLimitTypeID
		
		IF @@ROWCOUNT = 0
		BREAK;
		WAITFOR DELAY '00:00:00.010'
	END

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


