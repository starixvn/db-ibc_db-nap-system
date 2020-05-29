/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_CustInsert] 
	@Username VARCHAR(30) = NULL,
	@BetLimitTypeID INT = NULL,
	@MaxBet MONEY = NULL,
	@MaxPerMatch MONEY = NULL,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(MAX) = '' OUTPUT,
	@UserId INT = 0 ,
	@IP	VARCHAR(15) = ''
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - Insert new CustSetting 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:
	- @ErrorCode: 
		1: The bet limit type exist already.

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(MAX) = '' 
	EXEC NAP_BLControl_CustInsert 
		@Username = 'member01',
		@BetLimitTypeID  = 1,
		@MaxBet  = 100,
		@MaxPerMatch  = 1000,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT,
		@UserId = 8

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31753
	DECLARE @site  NVARCHAR(50), @BetLimitType VARCHAR(50)

	SET @StartRun = GETDATE()

	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey='CustomerManagement',
		@FunctionKey='BetLimitTypeControl',
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		RETURN

	DECLARE @CustID INT

	EXEC NAP_BLControl_CustCheck 
		@Username = @Username,
		@BetLimitTypeID = @BetLimitTypeID,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT,
		@CustID = @CustID OUTPUT

	IF @ErrorCode <> 0
		RETURN

	INSERT INTO BetLimitControlCustSetting (CustID,BetLimitTypeID,MaxBet,MaxPerMatch)
	SELECT @CustID,@BetLimitTypeID,@MaxBet,@MaxPerMatch

	SELECT @site = Site FROM Customer c WITH(NOLOCK) WHERE c.custid = @CustID
	SELECT @BetLimitType = BetLimitType FROM BetLimitControlType WITH(NOLOCK) WHERE BetLimitTypeID = @BetLimitTypeID

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @LogData VARCHAR(500)
	SELECT  @LogData = '<R '
						+ 'Type="'+ coalesce(cast(@BetLimitType as varchar(50)),space(1)) + '" ' 
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


