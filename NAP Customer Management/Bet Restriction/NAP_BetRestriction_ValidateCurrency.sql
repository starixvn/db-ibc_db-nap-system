/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_ValidateCurrency] (
	  @ExchangeID		INT
	 ,@SportType		SMALLINT = 1
	 ,@CurentType		TINYINT = NULL
	 ,@NewType			TINYINT
	 ,@IsAllowInsertUpdate	BIT = 0 OUTPUT
)
AS
/*
	Created: 20190815@Eden
	Task : Check exists Bet Restriction Currency for insert/update type 
	DB: DBACC/bodb02
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]

	Parameter explanation:
	@IsAllowInsertUpdate =: 
			0 : Validate failed , existing record
			1 : succeed , can be inserted

	Example: 
	DECLARE @IsAllowInsertUpdate BIT 
	EXEC NAP_BetRestriction_ValidateCurrency
		@ExchangeID = 5,  @SportType = 1,
		@CurentType = 1,
		@NewType = 1,
		@IsAllowInsertUpdate = @IsAllowInsertUpdate OUTPUT
	SELECT @IsAllowInsertUpdate
	*/
BEGIN	
	SET @IsAllowInsertUpdate = 1	

	IF @CurentType IS NOT NULL --Update
	BEGIN
		IF @CurentType = ISNULL(@NewType,@CurentType) OR @CurentType = 0
		BEGIN
			SET @IsAllowInsertUpdate = 1
			RETURN
		END

		IF EXISTS( SELECT TOP 1 1 
				   FROM BetRestriction_Currency WITH(NOLOCK)
				   WHERE ExchangeID = @ExchangeID AND SportType = @SportType AND Type <> @CurentType
				   ) 
			SET @IsAllowInsertUpdate = 0 
	END
	ELSE --Insert
	BEGIN
		IF EXISTS( SELECT TOP 1 1 
				   FROM BetRestriction_Currency WITH(NOLOCK)
				   WHERE ExchangeID = @ExchangeID AND SportType = @SportType) AND @NewType = 0
			SET @IsAllowInsertUpdate = 0 
		
		IF EXISTS( SELECT TOP 1 1 
				   FROM BetRestriction_Currency WITH(NOLOCK)
				   WHERE ExchangeID = @ExchangeID AND SportType = @SportType AND Type IN( @NewType,0) )
			SET @IsAllowInsertUpdate = 0 
	END
	                     
END
GO


