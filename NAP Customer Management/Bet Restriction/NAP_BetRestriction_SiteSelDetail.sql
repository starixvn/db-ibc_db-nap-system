/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_SiteSelDetail] 
	 @SiteID		INT = NULL
	,@SportType		SMALLINT = 1
AS
/*
	Created: 20190815@Eden
	Task : Get Bet Restriction Site Detail for Update
	DB: DBACC/bodb02
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]

	Example: EXEC NAP_BetRestriction_SiteSelDetail @SiteID = 1, @SportType = 1
	
	
	*/
BEGIN
	SELECT s.[site],
		   bs.SiteID,
		   bs.SportType,
		   bs.LiveBetAccept, 
		   bs.SeizeBetTicket, 
		   bs.FollowAccount AS FollowAccountID,
		   ci.username AS FollowAccount
	FROM BetRestriction_Site bs WITH(NOLOCK)
		 INNER JOIN [Site] s WITH(NOLOCK) ON bs.SiteID = s.siteid
		 LEFT JOIN CustInfo ci WITH(NOLOCK) ON ci.custid = bs.FollowAccount
	WHERE bs.siteid = @SiteID AND SportType = @SportType
		  
END
GO


