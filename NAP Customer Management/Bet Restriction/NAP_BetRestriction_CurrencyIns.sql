/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CurrencyIns] (
	  @ExchangeID		INT
	 ,@UserId			INT
	 ,@IP				VARCHAR(15) = ''
	 ,@SportType		SMALLINT = 1
	 ,@Type				TINYINT
	 ,@LiveBetAccept	SMALLINT
	 ,@SeizeBetTicket	TINYINT = NULL
	 ,@FollowAccount	NVARCHAR(50) = NULL
	 ,@ErrMsg			NVARCHAR(MAX) = '' OUTPUT	
	 ,@ErrCode			TINYINT = 0 OUTPUT
)
AS
/*
	Created: 20190815@Eden
	Task : Insert Bet Restriction for Currency
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP [RedmineID: #117727]

	Parameter explanation:
	@ErrCode =: 
			0 - succeed 
			2 - This Currency/Type has already exists in the Bet Restriction list.
			3 - Invalid 8RM Account.

	Example: 
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_CurrencyIns
		@ExchangeID = 12, 
		@userid = 10,
		@Type = 2,
		@LiveBetAccept = 10 , 
		@SeizeBetTicket = 30 , 
		@FollowAccount = '8RM888',
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT
	SELECT @ErrCode, @ErrMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31707
	DECLARE @FollowAccountID INT ,@Currency	NVARCHAR(50),@vType VARCHAR(10)

	SET @ErrCode = 0
	SET @StartRun = GETDATE()

	EXEC NAP_BetRestriction_ValidateCurrency
		@ExchangeID = @ExchangeID,  
		@SportType = @SportType,
		@NewType = @Type,
		@ErrCode = @ErrCode OUTPUT

	IF @ErrCode > 0
	BEGIN
		SELECT @ErrMsg = CASE WHEN @ErrCode = 1 THEN 'Invalid Currency.' 
							  WHEN @ErrCode = 2 THEN 'This currency has already exists in the Bet Restriction list.' 
						 END
		RETURN
	END

	EXEC NAP_BetRestriction_ValidateFollowAccount
		@FollowAccount = @FollowAccount,
		@FollowAccountID  = @FollowAccountID OUTPUT,
		@ExchangeID = @ExchangeID

	IF @FollowAccount IS NOT NULL AND @FollowAccountID IS NULL
	BEGIN
		SET @ErrCode = 3
		SELECT @ErrMsg = 'Invalid 8RM Account.' 
		RETURN
	END

	SELECT @Currency = Currency FROM exchange WITH(NOLOCK) WHERE exchangeid = @ExchangeID
	SELECT @vType = CASE WHEN @Type = 0 THEN 'All' 
						 WHEN @Type = 1 THEN 'Credit'
						 WHEN @Type = 2 THEN 'Licensee' END
	
	BEGIN TRY
		INSERT INTO BetRestriction_Currency(
			ExchangeID, 
			SportType,
			[Type],
			LiveBetAccept, 
			SeizeBetTicket, 
			FollowAccount
		   )
		SELECT  @ExchangeID, 
				@SportType,
				@Type,
				@LiveBetAccept, 
				@SeizeBetTicket, 
				@FollowAccountID
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SELECT @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @LogDataNew VARCHAR(500)
	SELECT  @LogDataNew = '<R '
						+ 'Currency="'+ coalesce(cast(@Currency as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'Type="'+ coalesce(cast(@vType as varchar(50)),space(1)) + '" ' 
						+ 'LBA="'+ coalesce(cast(@LiveBetAccept as varchar(50)),'FUL') + '" '
						+ 'SBT="'+ CASE WHEN @SeizeBetTicket IS NULL THEN 'FUL' WHEN @SeizeBetTicket = 0 THEN 'None' ELSE cast(@SeizeBetTicket as varchar(50)) END  + '" '  
						+ 'FA="'+ coalesce(cast(@FollowAccount as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />'
		
	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserId				= @UserId,
		--@CustId				= @CustId,
		@ActionId			= @ActionID,
		@TrackingValue		= @LogDataNew,
		@Duration			= @Duration 
END
GO


