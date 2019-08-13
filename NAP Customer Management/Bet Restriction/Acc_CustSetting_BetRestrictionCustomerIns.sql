/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCustomerIns] (
	  @CustID			INT
	 ,@SportType		SMALLINT = 1
	 ,@LiveBetAccept	SMALLINT
	 ,@SeizeBetTicket	TINYINT = NULL
	 ,@MaxBet			MONEY = NULL
	 ,@MaxPerMatch		MONEY = NULL
	 ,@FollowAccount	INT	= NULL
)
AS
/*
	Created: 20190807@Eden
	Task : Insert Bet Restriction for Customer
	DB: DBCUST/CustDB
	Original:

	Example: 
	EXEC Acc_CustSetting_BetRestrictionCustomerIns
		@CustID = 1176092, 
		@LiveBetAccept = -5 , 
		@SeizeBetTicket = 50 , 
		@MaxBet = 100.00, 
		@MaxPerMatch = 1000.00, 
		@FollowAccount = 4444;
	
	
	*/
BEGIN
	
	INSERT INTO BetRestriction_Customer(
		CustID, 
        SportType, 
        LiveBetAccept, 
        SeizeBetTicket, 
        MaxBet, 
        MaxPerMatch, 
        FollowAccount
       )
    SELECT  @CustID, 
            @SportType, 
            @LiveBetAccept, 
            @SeizeBetTicket, 
            @MaxBet, 
            @MaxPerMatch, 
            @FollowAccount
END
GO


