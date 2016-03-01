USE [bodb02]
GO

ALTER PROCEDURE [dbo].[NAP_ColossusBets_BonusTicket_SelList]
AS
/*
Created: 20160215@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBACC.bodb02
Original:
Revisions:
	- 20160215@bobby.nguyen: #52058 - Update for CB change request - Insert bonus ticket
	- 20160224@bobby.nguyen: #52058 - Correct translog status when winning Jack Pot price
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;
    
    	
    SELECT b.translogid AS refno
		, b.custid
		, b.username
		, b.custom2 		AS pool
		, b.winlostdate
		, bm.winamount
		, bm.[status]
		, bm.[statusID]
		, ISNULL(bm.match, '-') AS match
		, ISNULL(bm.league, '-') AS league
		, ISNULL(bm.choice, '-') AS choice
		, ISNULL(bm.result, '-') AS result
		
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
	
	WHERE b.gameId	= 18000
		--AND b.statusID 	= 112
		
	ORDER BY b.translogid DESC
		
END
GO
GRANT EXECUTE ON [dbo].[NAP_ColossusBets_BonusTicket_SelList] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_ColossusBets_BonusTicket_SelList] TO [vnteam]
GO

    