/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionSiteIns] (
	  @SiteID			INT
	 ,@SportType		SMALLINT = 1
	 ,@LiveBetAccept	SMALLINT
	 ,@SeizeBetTicket	TINYINT = NULL
	 ,@FollowAccount	INT	= NULL
)
AS
/*
	Created: 20190807@Eden
	Task : Insert Bet Restriction for Site
	DB: DBCUST/CustDB
	Original:

	Example: 
	EXEC Acc_CustSetting_BetRestrictionSiteIns
		@SiteID = 234, 
		@LiveBetAccept = 5 , 
		@SeizeBetTicket = 20 , 
		@FollowAccount = 1111;
	
	
	*/
BEGIN
	
	INSERT INTO BetRestriction_Site(
		SiteID, 
		SportType,
        LiveBetAccept, 
        SeizeBetTicket, 
        FollowAccount
       )
    SELECT  @SiteID, 
            @SportType,
			@LiveBetAccept, 
            @SeizeBetTicket, 
            @FollowAccount
END
GO


