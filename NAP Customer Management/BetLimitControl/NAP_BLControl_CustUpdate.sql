/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_CustUpdate] 
	@CustID INT = NULL,
	@BetLimitTypeID INT = NULL,
	@NewBetLimitTypeID INT = NULL,
	@MaxBet MONEY = NULL,
	@MaxPerMatch MONEY = NULL,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(MAX) = '' OUTPUT,
	@UserId INT = 0 ,
	@IP	VARCHAR(15) = ''
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - Update CustSetting 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:
	- @ErrorCode: 
		3: Invalid Bet Limit Type. Please try again.
		4: This record no longer exists in the Bet Limit Control List.
	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(MAX) = '' 
	EXEC NAP_BLControl_CustUpdate 
		@CustID = 1176092,
		@BetLimitTypeID  = 1,
		@NewBetLimitTypeID  = 1,
		@MaxBet  = 100,
		@MaxPerMatch  = 1000,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT,
		@UserId = 8

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31754
	DECLARE @site  NVARCHAR(50), @BetLimitType VARCHAR(50),@NewBetLimitType VARCHAR(50)

	SET @StartRun = GETDATE()

	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey='CustomerManagement',
		@FunctionKey='BetLimitTypeControl',
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		RETURN
	
	DECLARE @OldMaxBet MONEY ,
			@OldMaxPerMatch MONEY

	SELECT @OldMaxBet = t.MaxBet
		,@OldMaxPerMatch = t.MaxPerMatch
	FROM BetLimitControlCustSetting t WITH(NOLOCK)
	WHERE CustID = @CustID and BetLimitTypeID = @BetLimitTypeID 

	IF @@ROWCOUNT = 0
	BEGIN
		SET @ErrorCode = 4
		SELECT @ErrorMsg = 'This record does not exists in the Bet Limit Control List.'
		RETURN
	END

	IF NOT EXISTS( SELECT TOP 1 1 FROM BetLimitControlType t WITH(NOLOCK) WHERE BetLimitTypeID = @NewBetLimitTypeID )
	BEGIN
		SELECT @ErrorCode = 3 ,
			@ErrorMsg = 'Invalid Bet Limit Type. Please try again.'
		RETURN
	END

	SELECT @NewBetLimitTypeID = ISNULL(@NewBetLimitTypeID,@BetLimitTypeID)

	IF EXISTS(  SELECT TOP 1 1 
				FROM BetLimitControlCustSetting WITH(NOLOCK)
				WHERE CustID = @CustID and BetLimitTypeID = @NewBetLimitTypeID )
				AND @NewBetLimitTypeID <> @BetLimitTypeID
	BEGIN
		SELECT @ErrorCode = 2
			  ,@ErrorMsg = 'The selected user has this bet limit type already.'
		RETURN
	END

	UPDATE t
	SET t.BetLimitTypeID = @NewBetLimitTypeID,
		t.MaxBet = @MaxBet,
		t.MaxPerMatch = @MaxPerMatch
	FROM BetLimitControlCustSetting t WITH(ROWLOCK,UPDLOCK)
	WHERE t.CustID = @CustID AND t.BetLimitTypeID = @BetLimitTypeID

	SELECT @site = Site FROM Customer c WITH(NOLOCK) WHERE c.custid = @CustID
	SELECT @BetLimitType = BetLimitType FROM BetLimitControlType WITH(NOLOCK) WHERE BetLimitTypeID = @BetLimitTypeID
	SELECT @NewBetLimitType = BetLimitType FROM BetLimitControlType WITH(NOLOCK) WHERE BetLimitTypeID = @NewBetLimitTypeID

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @OldLogData VARCHAR(500),@NewLogData VARCHAR(500)
	SELECT  @OldLogData = '<R '
						+ 'Type="'+ coalesce(cast(@BetLimitType as varchar(50)),space(1)) + '" ' 
						+ 'maxb="'+ coalesce(cast(@OldMaxBet as varchar(50)),space(1)) + '" ' 
						+ 'mpm="'+ coalesce(cast(@OldMaxPerMatch as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />',
			@NewLogData = '<R '
						+ 'Type="'+ coalesce(cast(@NewBetLimitType as varchar(50)),space(1)) + '" ' 
						+ 'maxb="'+ coalesce(cast(@MaxBet as varchar(50)),space(1)) + '" ' 
						+ 'mpm="'+ coalesce(cast(@MaxPerMatch as varchar(50)),space(1)) + '" ' 
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


