/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionSiteSelDetail] 
	 @SiteID		INT = NULL
	,@SportType		SMALLINT = 1
AS
/*
	Created: 20190807@Eden
	Task : Get Bet Restriction Site 
	DB: DBCUST/CustDB
	Original:

	Example: EXEC Acc_CustSetting_BetRestrictionSiteSelDetail @SiteID = 234
	
	
	*/
BEGIN
	SELECT s.[site],
		   bs.LiveBetAccept, 
		   bs.SeizeBetTicket, 
		   bs.FollowAccount AS FollowAccountID,
		   ci.username AS FollowAccount
	FROM BetRestriction_Site bs WITH(NOLOCK)
		 JOIN [Site] s WITH(NOLOCK) ON bs.SiteID = s.siteid
		 LEFT JOIN CustInfo ci WITH(NOLOCK) ON ci.custid = bs.FollowAccount
	WHERE bs.siteid = @SiteID AND SportType = @SportType
		  
END
GO


