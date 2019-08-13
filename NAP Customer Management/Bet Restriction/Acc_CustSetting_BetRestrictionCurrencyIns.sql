/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCurrencyIns] (
	  @ExchangeID		INT
	 ,@SportType		SMALLINT = 1
	 ,@Type				TINYINT
	 ,@LiveBetAccept	SMALLINT
	 ,@SeizeBetTicket	TINYINT = NULL
	 ,@FollowAccount	INT	= NULL
)
AS
/*
	Created: 20190807@Eden
	Task : Insert Bet Restriction for Currency
	DB: DBCUST/CustDB
	Original:

	Example: 
	EXEC Acc_CustSetting_BetRestrictionCurrencyIns
		@ExchangeID = 5, 
		@Type = 1,
		@LiveBetAccept = 10 , 
		@SeizeBetTicket = 30 , 
		@FollowAccount = 2222;
	*/
BEGIN
	
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
            @FollowAccount
END
GO


