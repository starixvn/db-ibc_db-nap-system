/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCustomerDel] 
	  @CustID		INT = NULL
	 ,@SportType    SMALLINT = 1
AS
/*
	Created: 20190807@Eden
	Task : Delete Bet Restriction Customer 
	DB: DBCUST/CustDB
	Original:

	Example: EXEC Acc_CustSetting_BetRestrictionCustomerDel @CustID = 1176092	
	
	*/
BEGIN
	DELETE
	FROM BetRestriction_Customer WITH(UPDLOCK,ROWLOCK)
	WHERE CustID = @CustID AND SportType = @SportType	  
END
GO


