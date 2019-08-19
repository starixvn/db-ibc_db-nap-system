/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CurrencyUpd] (
	  @ExchangeID		INT
	 ,@UserId			INT
	 ,@CurrentType		TINYINT
	 ,@NewType			TINYINT
	 ,@SportType		SMALLINT = 1
	 ,@LiveBetAccept	SMALLINT
	 ,@SeizeBetTicket	TINYINT = NULL
	 ,@FollowAccount	NVARCHAR(50) = NULL
	 ,@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
	 ,@ErrCode			TINYINT = 0 OUTPUT
)
AS
/*
	Created: 20190815@Eden
	Task : Update Bet Restriction for Currency
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP [RedmineID: #117727]

	Parameter explanation:
	@ErrCode =: 
			0 - succeed 
			1 - Invalid Currency.
			2 - This Currency/Type has already exists in the Bet Restriction list.
			3 - Invalid 8RM Account.

	Example: 
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_CurrencyUpd
		@ExchangeID = 5, 
		@UserID = 8,
		@CurrentType = 1,
		@NewType = 0,
		@LiveBetAccept = 15 , 
		@SeizeBetTicket = 60 , 
		@FollowAccount = '8RM888',
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT
	SELECT @ErrCode, @ErrMsg
	
	*/
BEGIN	
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31708
	DECLARE @FollowAccountID INT
	DECLARE @LiveBetAccept_Old  SMALLINT, 
			@SeizeBetTicket_Old TINYINT, 
			@FollowAccount_Old  INT;

	SET @ErrCode = 0
	SET @StartRun = GETDATE()

	EXEC NAP_BetRestriction_ValidateCurrency
		@ExchangeID = @ExchangeID,  
		@SportType = @SportType,
		@CurrentType = @CurrentType,
		@NewType = @NewType,
		@ErrCode = @ErrCode OUTPUT

	IF @ErrCode > 0
	BEGIN
		SELECT @ErrMsg = CASE WHEN @ErrCode = 1 THEN 'Invalid Currency.' 
							  WHEN @ErrCode = 2 THEN 'This Currency/Type has already exists in the Bet Restriction list.' 
						 END
		RETURN
	END

	EXEC NAP_BetRestriction_ValidateFollowAccount
		@FollowAccount = @FollowAccount,
		@FollowAccountID  = @FollowAccountID OUTPUT

	IF @FollowAccount IS NOT NULL AND @FollowAccountID IS NULL
	BEGIN
		SET @ErrCode = 3
		SELECT @ErrMsg = 'Invalid 8RM Account.' 
		RETURN
	END

	SELECT @LiveBetAccept_Old = LiveBetAccept, 
		   @SeizeBetTicket_Old = SeizeBetTicket, 
		   @FollowAccount_Old = FollowAccount
	FROM BetRestriction_Currency WITH(NOLOCK)
	WHERE ExchangeID = @ExchangeID	
		  ANd Type = @CurrentType
		  AND SportType = @SportType;
	
	IF	@LiveBetAccept_Old = @LiveBetAccept 
		AND ISNULL(@SeizeBetTicket_Old,0) = ISNULL(@SeizeBetTicket,0)
		AND ISNULL(@FollowAccount_Old ,0)= ISNULL(@FollowAccountID,0)
		AND ISNULL(@CurrentType,-1) = ISNULL(@NewType,-1)
	BEGIN
		SELECT @ErrMsg = N'No change'
		RETURN
	END
	
	BEGIN TRY
		UPDATE BetRestriction_Currency WITH(ROWLOCK)
		SET	LiveBetAccept 	= @LiveBetAccept, 
			SeizeBetTicket  = @SeizeBetTicket, 
			FollowAccount	= @FollowAccountID,
			[Type]			= ISNULL(@NewType,[Type])
		WHERE ExchangeID = @ExchangeID 
			  AND [Type] = @CurrentType
			  AND SportType = @SportType 
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SELECT @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)
	SELECT  @LogDataNew = '<R'
						+ 'ExchangeID="'+ coalesce(cast(@ExchangeID as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'Type="'+ coalesce(cast(@NewType as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAccept="'+ coalesce(cast(@LiveBetAccept as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicket="'+ coalesce(cast(@SeizeBetTicket as varchar(50)),space(1)) + '" ' 
						+ 'FollowAccount="'+ coalesce(cast(@FollowAccountID as varchar(50)),space(1)) + '" ' 
						+ ' />',
			@LogDataOld = '<R'
						+ 'ExchangeID="'+ coalesce(cast(@ExchangeID as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'Type="'+ coalesce(cast(@CurrentType as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAccept="'+ coalesce(cast(@LiveBetAccept_Old as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicket="'+ coalesce(cast(@SeizeBetTicket_Old as varchar(50)),space(1)) + '" ' 
						+ 'FollowAccount="'+ coalesce(cast(@FollowAccount_Old as varchar(50)),space(1)) + '" ' 
						+ ' />'
		

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserId				= @UserId,
		--@CustId				= @CustId,
		@ActionId			= @ActionID,
		@TrackingValue		= @LogDataNew,
		@TrackingValue2		= @LogDataOld,
		@Duration			= @Duration                    	                      
END
GO


