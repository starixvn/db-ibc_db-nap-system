/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_ValidateCurrency] (
	  @ExchangeID		INT
	 ,@SportType		SMALLINT = 1
	 ,@CurrentType		TINYINT = NULL
	 ,@NewType			TINYINT
	 ,@ErrCode			TINYINT = 0 OUTPUT
)
AS
/*
	Created: 20190815@Eden
	Task : Check exists Bet Restriction Currency for insert/update type 
	DB: DBCUST/CUSTDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]

	Parameter explanation:
	@ErrCode =: 
			0 - succeed , can be inserted/updated
			1 - Invalid Currency.
			2 - This Currency/Type has already exists in the Bet Restriction list.

	Example: 
	DECLARE @ErrCode TINYINT 
	EXEC NAP_BetRestriction_ValidateCurrency
		@ExchangeID = 33,  
		@SportType = 1,
		--@CurrentType = 1,
		@NewType = 0,
		@ErrCode = @ErrCode OUTPUT
	SELECT @ErrCode
	*/
BEGIN	
	SET @ErrCode = 0	

	IF NOT EXISTS ( SELECT TOP 1 1 FROM exchange WITH(NOLOCK) WHERE exchangeid = @ExchangeID )
	BEGIN
		SET @ErrCode = 1
		RETURN
	END 

	IF @CurrentType IS NOT NULL --Update
	BEGIN
		IF @CurrentType = ISNULL(@NewType,@CurrentType) OR @CurrentType = 0
		BEGIN
			RETURN
		END

		IF EXISTS( SELECT TOP 1 1 
				   FROM BetRestriction_Currency WITH(NOLOCK)
				   WHERE ExchangeID = @ExchangeID AND SportType = @SportType AND Type <> @CurrentType
				   ) 
			SET @ErrCode = 2
	END
	ELSE --Insert
	BEGIN
		IF EXISTS( SELECT TOP 1 1 
				   FROM BetRestriction_Currency WITH(NOLOCK)
				   WHERE ExchangeID = @ExchangeID AND SportType = @SportType) AND @NewType = 0
			SET @ErrCode = 2
		
		IF EXISTS( SELECT TOP 1 1 
				   FROM BetRestriction_Currency WITH(NOLOCK)
				   WHERE ExchangeID = @ExchangeID AND SportType = @SportType AND Type IN( @NewType,0) )
			SET @ErrCode = 2
	END
	                     
END
GO


