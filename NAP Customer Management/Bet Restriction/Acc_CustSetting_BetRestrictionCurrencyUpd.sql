/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCurrencyUpd] (
	  @ExchangeID		INT
	 ,@CurentType		TINYINT
	 ,@NewType			TINYINT
	 ,@SportType		SMALLINT = 1
	 ,@LiveBetAccept	SMALLINT
	 ,@SeizeBetTicket	TINYINT 
	 ,@FollowAccount	INT
)
AS
/*
	Created: 20190807@Eden
	Task : Update Bet Restriction for Currency
	DB: DBCUST/CustDB
	Original:

	Example: 
	EXEC Acc_CustSetting_BetRestrictionCurrencyUpd
		@ExchangeID = 5, 
		@CurentType = 1,
		@NewType = 1,
		@LiveBetAccept = 15 , 
		@SeizeBetTicket = 60 , 
		@FollowAccount = 9999;
	
	
	*/
BEGIN	
	UPDATE BetRestriction_Currency WITH(ROWLOCK)
	SET	LiveBetAccept 	= @LiveBetAccept, 
        SeizeBetTicket  = @SeizeBetTicket, 
        FollowAccount	= @FollowAccount,
		[Type]			= ISNULL(@NewType,[Type])
    WHERE ExchangeID = @ExchangeID 
		  AND [Type] = @CurentType
		  AND SportType = @SportType
			                      
END
GO


