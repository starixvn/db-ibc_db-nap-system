/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_TypeUpdate] 
	@BetLimitTypeID INT,
	@BetLimitType VARCHAR(50) = NULL,
	@ProductList VARCHAR(200) = '',
	@SporttypeList VARCHAR(MAX) = '',
	@BettypeList VARCHAR(MAX) =  '',
	@LiveIndicator	TINYINT = NULL,
	@LeagueGroupList VARCHAR(MAX) = '',
	@IsExcludedLeagueGroup BIT = 0,
	@LeagueList VARCHAR(MAX) =  '',
	@BeginTime TIME = NULL,
	@EndTime TIME = NULL,
	@RestrictVIP BIT = NULL,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(MAX) = '' OUTPUT,
	@UserId INT = 0 ,
	@IP	VARCHAR(15) = ''
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - Update Type 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
		- 20200525@Eden: Create New SP  [RedmineID: #132736]
		- 20220303@Johnson: Add league group [RedmineID: #156808]
		- 20240621@Winfred: Bet Limit Control - Remove validation and change UI for League Group ID [redmine:#206358]
		- 20240725@Tacy: Remove linked-server/cross-db on NAP_UserControl [redmineID: #208402]

	Parameter explanation:
	- @LiveIndicator : 0 : NonLive , 1: Live , 2 : Both, 3 : All
	- @ErrorCode: 
		1: The bet limit type is no longer exists.

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(MAX) = '' 
	EXEC NAP_BLControl_TypeUpdate 
		@BetLimitTypeID = 1,
		@BetLimitType = 'TypeAA',
		@ProductList = '0', 
		@SporttypeList = '0',
		@BettypeList = '0',
		@LiveIndicator = 3,
		@LeagueGroupList = '',
		@LeagueList =  '',
		@BeginTime = NULL,
		@EndTime = NULL,
		@RestrictVIP = 1,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT,
		@UserId = 8

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31751
	DECLARE @Old_BetLimitType VARCHAR(50),
			@Old_BeginTime TIME,
			@Old_EndTime TIME,
			@Old_LiveIndicator TINYINT,
			@Old_RestrictVIP BIT,
			@Old_ProductList VARCHAR(200),
			@Old_SportTypeList VARCHAR(MAX),
			@Old_BetTypeList VARCHAR(MAX),
			@Old_LeagueList VARCHAR(MAX),
			@Old_IsExcludedLeagueGroup VARCHAR(MAX),
			@Old_ExcludedLeagueGroupList VARCHAR(MAX),
			@Old_LeagueGroupList VARCHAR(MAX)

	SET @StartRun = GETDATE()

	IF NOT EXISTS( SELECT TOP 1 1 FROM BetLimitControlType t WITH(NOLOCK) WHERE t.BetLimitTypeID = @BetLimitTypeID )
	BEGIN
		SELECT @ErrorCode = 1 ,
			@ErrorMsg = 'The Bet Limit Type does not exist.'

		RETURN
	END

	SELECT @Old_BetLimitType = BetLimitType  
	FROM  BetLimitControlType t WITH(NOLOCK) 
	WHERE t.BetLimitTypeID = @BetLimitTypeID

	IF EXISTS( SELECT TOP 1 1 FROM BetLimitControlType t WITH(NOLOCK) WHERE t.BetLimitType = @BetLimitType ) AND @Old_BetLimitType <> @BetLimitType
	BEGIN
		SELECT @ErrorCode = 1 ,
			@ErrorMsg = 'The Bet Limit Type exists already.'

		RETURN
	END

	CREATE TABLE #ValidData (
		ProductID TINYINT,
		Sporttype SMALLINT,
		Bettype SMALLINT,
		LeagueGroupID INT,
		LeagueID INT
	)

	EXEC dbo.NAP_BLControl_SportBettypeCheck 
		@ProductList = @ProductList,
		@SporttypeList = @SporttypeList,
		@BettypeList = @BettypeList,
		@IsExcludedLeagueGroup = @IsExcludedLeagueGroup,
		@LeagueGroupList = @LeagueGroupList,
		@LeagueList = @LeagueList,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT

	IF @ErrorCode <> 0 
	BEGIN
		RETURN
	END 

	SELECT @EndTime = DATEADD(ms,59999,@EndTime)

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
		ExcludedLeagueGroupList VARCHAR(MAX),
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

	SELECT   @Old_BeginTime     		= BeginTime     
			,@Old_EndTime       		= EndTime       
			,@Old_LiveIndicator 		= LiveIndicator 
			,@Old_RestrictVIP   		= RestrictVIP   
			,@Old_ProductList   		= CASE WHEN IsAllProduct = 1 THEN '0' ELSE ProductList  END
			,@Old_SportTypeList 		= CASE WHEN IsAllSporttype = 1 THEN '0' ELSE SportTypeList  END  
			,@Old_BetTypeList   		= CASE WHEN IsAllBettype = 1 THEN '0' ELSE BetTypeList  END     
			,@Old_LeagueList    		= CASE WHEN IsAllLeague = 1 THEN '' ELSE LeagueList  END      
			,@Old_LeagueGroupList		= LeagueGroupList
			,@Old_ExcludedLeagueGroupList = ExcludedLeagueGroupList
			,@Old_IsExcludedLeagueGroup = CASE WHEN ExcludedLeagueGroupList <> '' THEN 1 ELSE 0 END
	FROM #OLdbetLimitTypeTbl

	--> Update BetLimitControlType
	UPDATE bc
	SET BeginTime = @BeginTime,
		EndTime = @EndTime,
		LiveIndicator = @LiveIndicator,
		RestrictVIP = @RestrictVIP,
		BetLimitType = @BetLimitType,
		ExcludedLeagueGroupList = CASE WHEN @IsExcludedLeagueGroup = 1 THEN @LeagueGroupList ELSE '' END
	FROM BetLimitControlType bc WITH(ROWLOCK,UPDLOCK)
	WHERE BetLimitTypeID = @BetLimitTypeID

	--> Reresh BetLimitControlTypeDetail
	MERGE BetLimitControlTypeDetail bc
	USING #ValidData t
		ON bc.ProductID = t.ProductID 
		AND bc.Sporttype = t.Sporttype
		AND bc.Bettype = t.Bettype 
		AND bc.LeagueGroupID = t.LeagueGroupID
		AND bc.LeagueID = t.LeagueID
		AND bc.BetLimitTypeID = @BetLimitTypeID
	WHEN NOT MATCHED THEN INSERT (BetLimitTypeID,ProductID,Sporttype,Bettype,LeagueGroupID,LeagueID)
						VALUES( @BetLimitTypeID,t.ProductID,t.Sporttype,t.Bettype,t.LeagueGroupID,t.LeagueID)

	WHEN NOT MATCHED BY SOURCE AND bc.BetLimitTypeID = @BetLimitTypeID
		THEN DELETE; 

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)


	DECLARE @OldLogData VARCHAR(500),@NewLogData VARCHAR(500)
	SELECT  @NewLogData = '<R '
						+ 'Type="'+ coalesce(cast(@BetLimitType as varchar(50)),space(1)) + '" ' 
						+ 'Product="'+ coalesce(cast(@ProductList as varchar(50)),space(1)) + '" ' 
						+ 'Sport="'+ coalesce(cast(@SporttypeList as varchar(50)),space(1)) + '" ' 
						+ 'BetType="'+ coalesce(cast(@BettypeList as varchar(50)),space(1)) + '" '
						+ 'LiveIndicator="'+ coalesce(cast(@LiveIndicator as varchar(50)),space(1)) + '" '  
						+ 'LeagueID="'+ coalesce(cast(@LeagueList as varchar(50)),space(1)) + '" ' 
						+ 'IsExcludedLeagueGroup="'+ coalesce(cast(@IsExcludedLeagueGroup as varchar(10)),space(1)) + '" ' 
						+ 'LeagueGroupList="'+ coalesce(cast(@LeagueGroupList as varchar(MAX)),space(1)) + '" ' 
						+ 'SpecificTime="'+ coalesce(cast(CASE WHEN @BeginTime IS NOT NULL THEN 1 ELSE 0 END as varchar(50)),space(1)) + '" ' 
						+ 'FromTime="'+ coalesce(cast(@BeginTime as varchar(50)),space(1)) + '" ' 
						+ 'ToTime="'+ coalesce(cast(@EndTime as varchar(50)),space(1)) + '" ' 
						+ 'RestrictVIP="'+ coalesce(cast(@RestrictVIP as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />',
			 @OldLogData = '<R '
						+ 'Type="'+ coalesce(cast(@Old_BetLimitType as varchar(50)),space(1)) + '" ' 
						+ 'Product="'+ coalesce(cast(@Old_ProductList as varchar(50)),space(1)) + '" ' 
						+ 'Sport="'+ coalesce(cast(@Old_SporttypeList as varchar(50)),space(1)) + '" ' 
						+ 'BetType="'+ coalesce(cast(@Old_BettypeList as varchar(50)),space(1)) + '" '
						+ 'LiveIndicator="'+ coalesce(cast(@Old_LiveIndicator as varchar(50)),space(1)) + '" '  
						+ 'LeagueID="'+ coalesce(cast(@Old_LeagueList as varchar(50)),space(1)) + '" ' 
						+ 'IsExcludedLeagueGroup="'+ coalesce(cast(@Old_IsExcludedLeagueGroup as varchar(10)),space(1)) + '" ' 
						+ 'LeagueGroupList="'+ coalesce(cast(CASE WHEN @Old_IsExcludedLeagueGroup = 1 THEN @Old_ExcludedLeagueGroupList ELSE @Old_LeagueGroupList END as varchar(MAX)),space(1)) + '" ' 
						+ 'SpecificTime="'+ coalesce(cast(CASE WHEN @Old_BeginTime IS NOT NULL THEN 1 ELSE 0 END as varchar(50)),space(1)) + '" ' 
						+ 'FromTime="'+ coalesce(cast(@Old_BeginTime as varchar(50)),space(1)) + '" ' 
						+ 'ToTime="'+ coalesce(cast(@Old_EndTime as varchar(50)),space(1)) + '" ' 
						+ 'RestrictVIP="'+ coalesce(cast(@Old_RestrictVIP as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />'

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserId				= @UserId,
		@ActionId			= @ActionID,
		@TrackingValue		= @NewLogData,
		@TrackingValue2		= @OldLogData,
		@Duration			= @Duration
END
GO


