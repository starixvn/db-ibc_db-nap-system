/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CurrencyUpd] (
	  @ExchangeID		INT
	 ,@UserId			INT
	 ,@IP				VARCHAR(15) = ''
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
			4 - This record no longer exists in the Bet Restriction List.

	Example: 
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_CurrencyUpd
		@ExchangeID = 35, 
		@UserID = 8,
		@CurrentType = 0,
		@NewType = 2,
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
			@FollowAccountID_Old  INT,
			@FollowAccount_Old	NVARCHAR(50),
			@Currency	NVARCHAR(50),
			@vNewType VARCHAR(10),
			@vCurrentType VARCHAR(10)

	SET @ErrCode = 0
	SET @StartRun = GETDATE()

	SELECT @LiveBetAccept_Old = LiveBetAccept, 
		   @SeizeBetTicket_Old = SeizeBetTicket, 
		   @FollowAccountID_Old = FollowAccount
	FROM BetRestriction_Currency WITH(NOLOCK)
	WHERE ExchangeID = @ExchangeID	
		  ANd Type = @CurrentType
		  AND SportType = @SportType;

	IF @@ROWCOUNT = 0
	BEGIN
		SET @ErrCode = 4
		SELECT @ErrMsg = 'This record no longer exists in the Bet Restriction List.'
		RETURN
	END

	EXEC NAP_BetRestriction_ValidateCurrency
		@ExchangeID = @ExchangeID,  
		@SportType = @SportType,
		@CurrentType = @CurrentType,
		@NewType = @NewType,
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
	
	IF	@LiveBetAccept_Old = @LiveBetAccept 
		AND ISNULL(@SeizeBetTicket_Old,-999) = ISNULL(@SeizeBetTicket,-999)
		AND ISNULL(@FollowAccountID_Old ,0)= ISNULL(@FollowAccountID,0)
		AND ISNULL(@CurrentType,-1) = ISNULL(@NewType,-1)
	BEGIN
		SELECT @ErrMsg = N'No change'
		RETURN
	END

	SELECT @Currency = Currency FROM exchange WITH(NOLOCK) WHERE exchangeid = @ExchangeID
	SELECT @vNewType = CASE WHEN @NewType = 0 THEN 'All' 
						 WHEN @NewType = 1 THEN 'Credit'
						 WHEN @NewType = 2 THEN 'Licensee' END
		  ,@vCurrentType = CASE WHEN @CurrentType = 0 THEN 'All' 
						 WHEN @CurrentType = 1 THEN 'Credit'
						 WHEN @CurrentType = 2 THEN 'Licensee' END
	
	SELECT @FollowAccount_Old = username FROM Customer WITH(NOLOCK) WHERE custid = @FollowAccountID_Old

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
	SELECT  @LogDataNew = '<R '
						+ 'Currency="'+ coalesce(cast(@Currency as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'Type="'+ coalesce(cast(@vNewType as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAccept="'+ coalesce(cast(@LiveBetAccept as varchar(50)),'NULL') + '" ' 
						+ 'SeizeBetTicket="'+ coalesce(cast(@SeizeBetTicket as varchar(50)),'NULL') + '" ' 
						+ 'FollowAccount="'+ coalesce(cast(@FollowAccount as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />',
			@LogDataOld = '<R '
						+ 'Currency="'+ coalesce(cast(@Currency as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'Type="'+ coalesce(cast(@vCurrentType as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAccept="'+ coalesce(cast(@LiveBetAccept_Old as varchar(50)),'NULL') + '" ' 
						+ 'SeizeBetTicket="'+ coalesce(cast(@SeizeBetTicket_Old as varchar(50)),'NULL') + '" ' 
						+ 'FollowAccount="'+ coalesce(cast(@FollowAccount_Old as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
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


