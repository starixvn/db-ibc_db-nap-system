/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CurrencySelDetail] 
	   @ExchangeID	INT = NULL
	  ,@SportType	SMALLINT = 1
	  ,@Type		TINYINT = NULL
AS
/*
	Created: 20190815@Eden
	Task : Get Bet Restriction Currency Detail for Update
	DB: DBACC/bodb02
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP [RedmineID: #117727]

	Example: EXEC NAP_BetRestriction_CurrencySelDetail @ExchangeID = 5, @SportType = 1, @Type = 1
	*/
BEGIN
	SELECT e.currency, 
		   bc.ExchangeID,
		   bc.SportType,
		   bc.[Type], 
		   bc.LiveBetAccept, 
		   bc.SeizeBetTicket, 
		   bc.FollowAccount AS FollowAccountID,
		   ci.username AS FollowAccount
	FROM BetRestriction_Currency bc WITH(NOLOCK)
		 INNER JOIN exchange e WITH(NOLOCK) ON bc.ExchangeID = e.exchangeid
		 LEFT JOIN CustInfo ci WITH(NOLOCK) ON ci.custid = bc.FollowAccount
	WHERE bc.ExchangeID = @ExchangeID AND bc.[Type] = @Type AND SportType = @SportType
END
GO


