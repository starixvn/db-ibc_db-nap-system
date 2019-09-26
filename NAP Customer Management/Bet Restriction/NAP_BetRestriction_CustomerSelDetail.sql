/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CustomerSelDetail] 
	  @CustID		INT = NULL
	 ,@SportType    SMALLINT = 1
AS
/*
	Created: 20190815@Eden
	Task : Get Bet Restriction Customer Detail for Update
	DB: DBACC/bodb02
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]

	Example: EXEC NAP_BetRestriction_CustomerSelDetail @CustID = 1176092, @SportType = 1
	
	*/
BEGIN
	SELECT bc.CustID,
		   bc.SportType,
		   ci.username as Account, 
		   bc.LiveBetAccept, 
		   bc.SeizeBetTicket, 
		   bc.MaxBet, 
		   bc.MaxPerMatch, 
		   bc.FollowAccount AS FollowAccountID,
		   rm.username AS [FollowAccount]
	FROM BetRestriction_Customer bc WITH(NOLOCK)
		 INNER JOIN custInfo ci WITH(NOLOCK) ON bc.CustID = ci.custid
		 LEFT JOIN custInfo rm WITH(NOLOCK) ON rm.custid = bc.[FollowAccount]
	WHERE bc.CustID = @CustID AND bc.SportType = @SportType	  
END
GO


