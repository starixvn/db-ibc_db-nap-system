/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Member_BetRestrictionInfoSel] 
	  @CustID		INT
	 ,@SportType    SMALLINT = 1
	 ,@IsTest		BIT = 0
AS
/*
	Created: 20190807@Eden
	Task : Get Bet Restriction info by CustID for MemberSite
	DB: DBCUST/CustDB
	Original:

	Example: EXEC Dot_Member_BetRestrictionInfoSel @CustID = 45703 ,@IsTest = 1
	
	
	*/
BEGIN
	DECLARE @IsShowData BIT = 0

	IF EXISTS(	SELECT 1
				FROM BetRestriction_Setting WITH (NOLOCK)
				WHERE SportType = 1 AND SettingType = 1
				  AND SettingStatus <=  @IsTest )
	BEGIN
		SET @IsShowData = 1
	END

	SELECT ci.CustID, 
		   COALESCE(bc.LiveBetAccept,agt.LiveBetAccept,mst.LiveBetAccept,spt.LiveBetAccept,bs.LiveBetAccept,bcu.LiveBetAccept) AS LiveBetAccept,
		   COALESCE(bc.SeizeBetTicket,agt.SeizeBetTicket,mst.SeizeBetTicket,spt.SeizeBetTicket,bs.SeizeBetTicket,bcu.SeizeBetTicket) AS SeizeBetTicket,
		   COALESCE(bc.FollowAccount,agt.FollowAccount,mst.FollowAccount,spt.FollowAccount,bs.FollowAccount,bcu.FollowAccount) AS FollowAccount,
		   COALESCE(bc.MaxBet,agt.MaxBet,mst.MaxBet,spt.MaxBet) AS MaxBet, 
		   COALESCE(bc.MaxPerMatch,agt.MaxPerMatch,mst.MaxPerMatch,spt.MaxPerMatch) AS MaxPerMatch
	FROM custInfo ci WITH (NOLOCK)
		JOIN Customer c WITH (NOLOCK) ON ci.custid = c.custid
		LEFT JOIN BetRestriction_Customer bc WITH (NOLOCK) ON bc.CustID = ci.custid AND bc.SportType = @SportType
		LEFT JOIN BetRestriction_Customer Agt  WITH (NOLOCK) ON Agt.CustID = ci.recommend AND agt.SportType = @SportType
		LEFT JOIN BetRestriction_Customer Mst  WITH (NOLOCK) ON Mst.CustID = ci.mrecommend  AND mst.SportType = @SportType
		LEFT JOIN BetRestriction_Customer Spt  WITH (NOLOCK) ON Spt.CustID = ci.srecommend  AND spt.SportType = @SportType
		LEFT JOIN Site s  WITH (NOLOCK) ON c.site = s.site
		LEFT JOIN BetRestriction_Site bs WITH (NOLOCK) ON s.siteid = bs.SiteID
		LEFT JOIN BetRestriction_Currency bcu WITH (NOLOCK) 
			ON ci.currency = bcu.ExchangeID 
			AND s.isLicensee = CASE WHEN bcu.Type = 2 THEN 1 
									WHEN bcu.Type = 1 THEN 0 
									WHEN bcu.Type = 0 THEN s.isLicensee 
								END
	WHERE ci.CustID = @CustID	
		  AND @IsShowData = 1  
END
GO


