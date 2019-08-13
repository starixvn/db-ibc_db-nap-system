/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionSiteDel] 
	  @SiteID		INT = NULL
	 ,@SportType	SMALLINT = 1
AS
/*
	Created: 20190807@Eden
	Task : Delete Bet Restriction Site 
	DB: DBCUST/CustDB
	Original:

	Example: EXEC Acc_CustSetting_BetRestrictionSiteDel @SiteID = 234
	
	
	*/
BEGIN
	DELETE
	FROM BetRestriction_Site WITH(UPDLOCK,ROWLOCK)
	WHERE siteid = @SiteID AND SportType = @SportType
		  
END
GO


