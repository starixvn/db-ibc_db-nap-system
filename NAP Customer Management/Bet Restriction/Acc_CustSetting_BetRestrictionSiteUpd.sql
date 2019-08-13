/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionSiteUpd] (
	  @SiteID			INT
	 ,@SportType		SMALLINT = 1
	 ,@LiveBetAccept	SMALLINT
	 ,@SeizeBetTicket	TINYINT 
	 ,@FollowAccount	INT	
)
AS
/*
	Created: 20190807@Eden
	Task : Update Bet Restriction for Site
	DB: DBCUST/CustDB
	Original:

	Example: 
	EXEC Acc_CustSetting_BetRestrictionSiteUpd
		@SiteID = 234, 
		@LiveBetAccept = 10 , 
		@SeizeBetTicket = 20 , 
		@FollowAccount = 1111;
	
	
	*/
BEGIN	
	UPDATE BetRestriction_Site WITH(ROWLOCK)
	SET LiveBetAccept = @LiveBetAccept, 
		SeizeBetTicket = @SeizeBetTicket, 
		FollowAccount = @FollowAccount
	WHERE SiteID = @SiteID AND SportType = @SportType
END
GO


