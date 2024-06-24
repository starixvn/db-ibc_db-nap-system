/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_TypeInsert] 
	@BetLimitType VARCHAR(100) = '',
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
	Task : Bet Limit Control - Insert new Type 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]
	- 20220302@Johnson: Add league group [RedmineID: #156808]
	- 20240621@Winfred: Bet Limit Control - Remove validation and change UI for League Group ID [redmine:#206358]
	Parameter explanation:
	- @LiveIndicator : 0 : NonLive , 1: Live , 2 : Both, 3 : All
	- @ErrorCode: 
		1: The Bet Limit Type exists already.

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(MAX) = '' 
	EXEC NAP_BLControl_TypeInsert 
		@BetLimitType = 'TypeD',
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
		@UserId = 8,
		@IP = '1.1.1.1'

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31750
	--DECLARE @site  NVARCHAR(50), @BetLimitType VARCHAR(50)

	SET @StartRun = GETDATE()

	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey='CustomerManagement',
		@FunctionKey='BetLimitTypeControl',
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		RETURN

	IF EXISTS( SELECT TOP 1 1 FROM BetLimitControlType t WITH(NOLOCK) WHERE t.BetLimitType = @BetLimitType )
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

	--> add more 59 seconds and 999 miliseconds
	SELECT @EndTime = DATEADD(ms,59999,@EndTime)
	DECLARE @Insert TABLE (BetLimitTypeID INT)

	INSERT INTO BetLimitControlType(BetLimitType,BeginTime,EndTime,LiveIndicator,RestrictVIP,ExcludedLeagueGroupList)
	OUTPUT Inserted.BetLimitTypeID INTO @Insert(BetLimitTypeID)
	SELECT @BetLimitType,@BeginTime,@EndTime,@LiveIndicator,@RestrictVIP, 
			CASE WHEN @IsExcludedLeagueGroup = 1 THEN @LeagueGroupList ELSE '' END

	INSERT INTO BetLimitControlTypeDetail(BetLimitTypeID,ProductID,Sporttype,Bettype,LeagueGroupID,LeagueID)
	SELECT BetLimitTypeID,ProductID,Sporttype,Bettype,LeagueGroupID,LeagueID
	FROM #ValidData v
		CROSS APPLY @Insert i

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
						+ 'IsExcludedLeagueGroup="'+ coalesce(cast(@IsExcludedLeagueGroup as varchar(50)),space(1)) + '" ' 
						+ 'LeagueGroupList="'+ coalesce(cast(@LeagueGroupList as varchar(MAX)),space(1)) + '" ' 
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

	DROP TABLE #ValidData
END
GO


