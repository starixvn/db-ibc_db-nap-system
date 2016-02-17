--NAP_ColossusBets_BonusTicket_Ins
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[NAP_ColossusBets_BonusTicket_SelDetail]
	@TranslogId 		BIGINT

AS
/*
Created: 20160215@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBACC.bodb02
Original:
Revisions:
	- 20160215@bobby.nguyen: #52058 - Update for CB change request - Insert bonus ticket
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;
    
    	
    SELECT translogid AS refno
		, custid
		, username
		, custom2 		AS pool
		, bm.winamount
		, bm.[status]
		, bm.[statusID]
		, bm.match
		, bm.league
		, bm.choice
		, bm.result
		
	FROM dbo.translog b WITH(NOLOCK) 
	CROSS APPLY (
		SELECT 
			winlost AS winamount
			,[status]
			,[statusID]
			,et.match
			,et.league
			,et.choice
			,et.result
		FROM dbo.bettransm WITH(NOLOCK) 
		OUTER APPLY [dbo].[f_NAP_CB_BonusTicket_EventInfo](transdesc) et
		WHERE custID 	= b.custID 
			AND refno 	= b.translogid 
			AND bettype = 18006
	) AS bm
	
	WHERE b.translogid 	= @TranslogId 
		AND b.statusID 	= 112
		AND b.gameId	= 18000
		
END
GO
GRANT EXECUTE ON [dbo].[NAP_ColossusBets_BonusTicket_SelDetail] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_ColossusBets_BonusTicket_SelDetail] TO [vnteam]
GO

    