/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCurrencyDel] 
	   @ExchangeID	INT = NULL
	  ,@SportType	SMALLINT = 1
	  ,@Type		TINYINT = NULL
AS
/*
	Created: 20190807@Eden
	Task : Delete Bet Restriction Currency 
	DB: DBCUST/CustDB
	Original:

	Example: EXEC Acc_CustSetting_BetRestrictionCurrencyDel @ExchangeID = 5 ,@Type = 1
	*/
BEGIN
	DELETE
	FROM  BetRestriction_Currency WITH(UPDLOCK,ROWLOCK)
	WHERE ExchangeID = @ExchangeID AND [Type] = @Type AND SportType = @SportType 
END
GO


