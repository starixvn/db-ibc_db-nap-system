/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_DefaultSetting_Upd] 
	@CustID INT = NULL,
	@BetLimitTypeID INT = NULL,
	@MaxBet MONEY = NULL,
	@MaxPerMatch MONEY = NULL,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(200) = '' OUTPUT,
	@UserId INT = 0 ,
	@IP	VARCHAR(15) = ''
AS
/*
	Created: 20200818@Eden
	Task : Update Bet Limit control default setting config
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200818@Eden: Create New SP  [RedmineID: #139701]
	- 20240904@Johnson: Apply Inhouse for BLC [redmine:#209892]
	Parameter explanation:

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(200) = '' 
	EXEC NAP_BLControl_DefaultSetting_Upd 
		@CustID = 1176092,
		@BetLimitTypeID  = 1,
		@MaxBet  = 100,
		@MaxPerMatch  = 1000,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT,
		@UserId = 8

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31761
	DECLARE @site  NVARCHAR(50), @BetLimitType VARCHAR(50)

	SET @StartRun = GETDATE()

	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey='CustomerManagement',
		@FunctionKey='DefaultBetLimitforNewMember',
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		RETURN
	
	DECLARE @OldMaxBet MONEY ,
			@OldMaxPerMatch MONEY

	SELECT @OldMaxBet = t.MaxBet
		,@OldMaxPerMatch = t.MaxPerMatch
	FROM BetLimitControlDefaultSetting t WITH(NOLOCK)
	WHERE CustID = @CustID and BetLimitTypeID = @BetLimitTypeID 

	IF @@ROWCOUNT = 0
	BEGIN
		SET @ErrorCode = 4
		SELECT @ErrorMsg = 'The Default Bet Limit Setting does not exist.'
		RETURN
	END

	UPDATE t
	SET t.MaxBet = @MaxBet,
		t.MaxPerMatch = @MaxPerMatch,
		t.RepUpdateTime = SYSDATETIME()
	FROM BetLimitControlDefaultSetting t WITH(ROWLOCK,UPDLOCK)
	WHERE t.CustID = @CustID AND t.BetLimitTypeID = @BetLimitTypeID

	SELECT @BetLimitType = BetLimitType FROM BetLimitControlType WITH(NOLOCK) WHERE BetLimitTypeID = @BetLimitTypeID

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @OldLogData VARCHAR(500),@NewLogData VARCHAR(500)
	SELECT  @OldLogData = '<R '
						+ 'Type="'+ coalesce(cast(@BetLimitType as varchar(50)),space(1)) + '" '
						+ 'mpm="'+ coalesce(cast(@OldMaxPerMatch as varchar(50)),space(1)) + '" ' 
						+ 'maxb="'+ coalesce(cast(@OldMaxBet as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />',
			@NewLogData = '<R '
						+ 'Type="'+ coalesce(cast(@BetLimitType as varchar(50)),space(1)) + '" ' 
						+ 'mpm="'+ coalesce(cast(@MaxPerMatch as varchar(50)),space(1)) + '" ' 
						+ 'maxb="'+ coalesce(cast(@MaxBet as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />'

	IF @site = 'CN88'
	BEGIN
		EXEC dbo.CS_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionID,
			@TrackingValue		= @NewLogData,
			@TrackingValue2		= @OldLogData,
			@Duration			= @Duration
	END
	ELSE -- MBC
	BEGIN
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionID,
			@TrackingValue		= @NewLogData,
			@TrackingValue2		= @OldLogData,
			@Duration			= @Duration
	END
END
GO


