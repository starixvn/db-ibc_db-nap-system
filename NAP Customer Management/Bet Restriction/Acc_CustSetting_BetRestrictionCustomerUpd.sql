/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCustomerUpd] (
	  @CustID			INT
	 ,@SportType		SMALLINT = 1
	 ,@LiveBetAccept	SMALLINT
	 ,@SeizeBetTicket	TINYINT 
	 ,@MaxBet			MONEY 
	 ,@MaxPerMatch		MONEY 
	 ,@FollowAccount	INT	
)
AS
/*
	Created: 20190807@Eden
	Task : Update Bet Restriction for Customer
	DB: DBCUST/CustDB
	Original:

	Example: 
	EXEC Acc_CustSetting_BetRestrictionCustomerUpd
		@CustID = 1176092, 
		@LiveBetAccept = 0 , 
		@SeizeBetTicket = 40 , 
		@MaxBet = 100.00, 
		@MaxPerMatch = 1000.00, 
		@FollowAccount = 5555;
	
	
	*/
BEGIN		
	UPDATE BetRestriction_Customer WITH(ROWLOCK)
	SET LiveBetAccept = @LiveBetAccept, 
		SeizeBetTicket = @SeizeBetTicket, 
		MaxBet = @MaxBet, 
		MaxPerMatch = @MaxPerMatch, 
		FollowAccount = @FollowAccount
	WHERE CustID = @CustID
		AND SportType = @SportType;                       
END
GO


