/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_DefaultSetting_Del] 
	@CustID INT = NULL,
	@BetLimitTypeID INT = NULL,
	@IsDownlineAffected BIT = 0,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(200) = '' OUTPUT,
	@UserId INT = 0 ,
	@IP	VARCHAR(15) = ''
AS
/*
	Created: 20200818@Eden
	Task : Delete Bet Limit control default setting config
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200818@Eden: Create New SP  [RedmineID: #139701]
	- 20240725@Tacy: Remove linked-server/cross-db on NAP_UserControl [redmineID: #208402]

	Parameter explanation:

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(200) = '' 
	EXEC NAP_BLControl_DefaultSetting_Del 
		@CustID = 1176070,
		@BetLimitTypeID  = 2,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT,
		@UserId = 8

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31762
	DECLARE @site  NVARCHAR(50), @BetLimitType VARCHAR(50)

	SET @StartRun = GETDATE()

	DECLARE @OldMaxBet MONEY ,
		@OldMaxPerMatch MONEY

	SELECT @BetLimitType = BetLimitType FROM BetLimitControlType WITH(NOLOCK) WHERE BetLimitTypeID = @BetLimitTypeID

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

	DECLARE @RoleID tinyint
	SELECT @RoleID = RoleID FROM custInfo  WITH(NOLOCK) WHERE custid = @CustID

	DELETE t
	FROM BetLimitControlDefaultSetting t WITH(ROWLOCK,UPDLOCK)
	WHERE CustID = @CustID and BetLimitTypeID = @BetLimitTypeID 

	--Check to remove all BLC of downlines 
	IF @IsDownlineAffected = 1
		EXEC [Acc_CustSetting_11]
			@CustID = @CustID,
			@BetLimitTypeID	= @BetLimitTypeID,
			@RoleID = @RoleID

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @LogData VARCHAR(500)
	SELECT  @LogData = '<R '
						+ 'Type="'+ coalesce(cast(@BetLimitType as varchar(50)),space(1)) + '" ' 
						+ 'mpm="'+ coalesce(cast(@OldMaxPerMatch as varchar(50)),space(1)) + '" '
						+ 'maxb="'+ coalesce(cast(@OldMaxBet as varchar(50)),space(1)) + '" ' 
						+ 'IsDownlineAffected="'+ coalesce(cast(@IsDownlineAffected as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />'

	IF @site = 'CN88'
	BEGIN
		EXEC dbo.CS_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionID,
			@TrackingValue		= @LogData,
			@Duration			= @Duration
	END
	ELSE -- MBC
	BEGIN
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionID,
			@TrackingValue		= @LogData,
			@Duration			= @Duration
	END
END
GO


