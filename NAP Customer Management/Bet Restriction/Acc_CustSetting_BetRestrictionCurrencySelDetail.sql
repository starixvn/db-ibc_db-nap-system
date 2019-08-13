/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCurrencySelDetail] 
	   @ExchangeID	INT = NULL
	  ,@SportType	SMALLINT = 1
	  ,@Type		TINYINT = NULL
AS
/*
	Created: 20190807@Eden
	Task : Get Bet Restriction Currency 
	DB: DBCUST/CustDB
	Original:

	Example: EXEC Acc_CustSetting_BetRestrictionCurrencySelDetail @ExchangeID = 5 ,@Type = 1
	*/
BEGIN
	SELECT e.currency, 
		   bc.[Type], 
		   bc.LiveBetAccept, 
		   bc.SeizeBetTicket, 
		   bc.FollowAccount AS FollowAccountID,
		   ci.username AS FollowAccount
	FROM BetRestriction_Currency bc WITH(NOLOCK)
		 JOIN exchange e WITH(NOLOCK) ON bc.ExchangeID = e.exchangeid
		 LEFT JOIN CustInfo ci WITH(NOLOCK) ON ci.custid = bc.FollowAccount
	WHERE bc.ExchangeID = @ExchangeID AND bc.[Type] = @Type AND SportType = @SportType
END
GO


