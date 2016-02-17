--NAP_ColossusBets_BonusTicket_Ins
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[NAP_ColossusBets_BonusTicket_SelRefInfo]
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
    
    	
    SELECT @TranslogId AS refno 
		, custID
		, username
		, custom2 		AS PoolName
		, Tranid3rd
		, eventID
	FROM dbo.translog b WITH(NOLOCK) 
	WHERE translogid 	= @TranslogId 
		AND statusID 	= 112
		AND gameId		= 18000
		AND EXISTS ( -- Jackpot win
			SELECT 1 
			FROM dbo.bettransm WITH(NOLOCK) 
			WHERE custID 	= b.custID 
				AND refno 	= b.translogid 
				AND bettype = 18005
				AND statusID= 112
		)
		-- AND NOT EXISTS ( -- Bonus ticket
			-- SELECT 1 
			-- FROM dbo.bettransm WITH(NOLOCK) 
			-- WHERE custID 	= b.custID 
				-- AND refno 	= b.translogid 
				-- AND bettype = 18006
		-- )
END
GO
GO
GRANT EXECUTE ON [dbo].[NAP_ColossusBets_BonusTicket_SelRefInfo] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_ColossusBets_BonusTicket_SelRefInfo] TO [vnteam]
GO
EXEC [dbo].[NAP_ColossusBets_BonusTicket_SelRefInfo] 1000000001435
GO