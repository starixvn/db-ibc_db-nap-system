/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCurrencyCheckType] (
	  @ExchangeID		INT
	 ,@SportType		SMALLINT = 1
	 ,@CurentType		TINYINT = NULL
	 ,@NewType			TINYINT
	 ,@IsAllowInsertUpdate	BIT = 0 OUTPUT
)
AS
/*
	Created: 20190807@Eden
	Task : Check exists Bet Restriction Currency 
	DB: DBCUST/CustDB
	Original:

	Example: 
	DECLARE @IsAllowInsertUpdate BIT 
	EXEC Acc_CustSetting_BetRestrictionCurrencyCheckType
		@ExchangeID = 5, 
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


