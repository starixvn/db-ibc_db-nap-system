/*<info serverAlias="DBCUST-CUSTDB" executers="Dot_Member" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Member_BetRestrictionInfoSel] 
	  @CustID		INT
	 ,@SportType    SMALLINT = 1
AS
/*
	Created: 20190807@Eden
	Task : Get Bet Restriction info by CustID for MemberSite
	DB: DBCUST/CustDB
	Original:

	Example: EXEC Dot_Member_BetRestrictionInfoSel @CustID = 35684622
	
	
	*/
BEGIN 
	DECLARE @siteID		INT, 
			@site		NVARCHAR(50), 
			@currency	INT, 
			@isLicensee BIT, 
			@recommend	INT, 
			@mrecommend INT, 
			@srecommend INT
	
	SELECT @CustID = c.CustID, 
		   @siteID = s.siteID, 
		   @site = s.site, 
		   @currency = c.currency, 
		   @isLicensee = s.isLicensee, 
		   @recommend = c.recommend, 
		   @mrecommend = c.mrecommend, 
		   @srecommend = c.srecommend
	FROM Customer c WITH(NOLOCK)
		  INNER JOIN Customer agent WITH(NOLOCK) ON c.recommend = agent.custid 
		  INNER JOIN Site s  WITH (NOLOCK) ON agent.site = s.site
	WHERE c.CustID = @CustID	
	
	SELECT ci.CustID,@SportType AS SportType,
		   COALESCE(bc.LiveBetAccept,agt.LiveBetAccept,mst.LiveBetAccept,spt.LiveBetAccept) AS LiveBetAccept,
		   COALESCE(bc.SeizeBetTicket,agt.SeizeBetTicket,mst.SeizeBetTicket,spt.SeizeBetTicket) AS SeizeBetTicket,
		   COALESCE(bc.FollowAccount,agt.FollowAccount,mst.FollowAccount,spt.FollowAccount) AS FollowAccount,
		   COALESCE(bc.MaxBet,agt.MaxBet,mst.MaxBet,spt.MaxBet) AS MaxBet, 
		   COALESCE(bc.MaxPerMatch,agt.MaxPerMatch,mst.MaxPerMatch,spt.MaxPerMatch) AS MaxPerMatch
	FROM (VALUES (@CustID)) AS ci(CustID)
		LEFT JOIN BetRestriction_Customer bc   WITH (NOLOCK) ON bc.CustID  = @custid AND bc.SportType = @SportType 
		LEFT JOIN BetRestriction_Customer Agt  WITH (NOLOCK) ON Agt.CustID = @recommend AND agt.SportType = @SportType 
		LEFT JOIN BetRestriction_Customer Mst  WITH (NOLOCK) ON Mst.CustID = @mrecommend  AND mst.SportType = @SportType 
		LEFT JOIN BetRestriction_Customer Spt  WITH (NOLOCK) ON Spt.CustID = @srecommend  AND spt.SportType = @SportType 

	SELECT @CustID AS CustID,
		   @SportType AS  SportType,
		   @Site Site,
		   bs.SiteID,
		   bs.LiveBetAccept,
		   bs.SeizeBetTicket,
		   bs.FollowAccount
	FROM   BetRestriction_Site bs WITH (NOLOCK) 
	WHERE  bs.SiteID = @SiteID AND bs.SportType = @SportType

	SELECT @CustID AS CustID,
		   @SportType AS  SportType,
		   bcu.ExchangeID,
		   bcu.LiveBetAccept,
		   bcu.SeizeBetTicket,
		   bcu.FollowAccount
	FROM   BetRestriction_Currency bcu WITH (NOLOCK) 
	WHERE  bcu.ExchangeID = @currency AND bcu.SportType = @SportType 
		   AND @isLicensee = CASE WHEN bcu.Type = 2 THEN 1 --Licensee
								  WHEN bcu.Type = 1 THEN 0 --Credit
								  WHEN bcu.Type = 0 THEN @isLicensee --All
							 END		   
END
GO


