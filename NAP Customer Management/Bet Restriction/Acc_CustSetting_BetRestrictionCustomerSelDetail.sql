/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCustomerSelDetail] 
	  @CustID		INT = NULL
	 ,@SportType    SMALLINT = 1
AS
/*
	Created: 20190807@Eden
	Task : Get Bet Restriction Customer By CustID to edit
	DB: DBCUST/CustDB
	Original:

	Example: EXEC Acc_CustSetting_BetRestrictionCustomerSelDetail @CustID = 1176092	
	
	*/
BEGIN
	SELECT bc.CustID,
		   ci.username as Account, 
		   bc.LiveBetAccept, 
		   bc.SeizeBetTicket, 
		   bc.MaxBet, 
		   bc.MaxPerMatch, 
		   rm.username AS [FollowAccount],
		   bc.FollowAccount AS FollowAccountID
	FROM BetRestriction_Customer bc WITH(NOLOCK)
		 JOIN custInfo ci WITH(NOLOCK) ON bc.CustID = ci.custid
		 LEFT JOIN custInfo rm WITH(NOLOCK) ON rm.custid = bc.[FollowAccount]
	WHERE bc.CustID = @CustID AND bc.SportType = @SportType	  
END
GO


