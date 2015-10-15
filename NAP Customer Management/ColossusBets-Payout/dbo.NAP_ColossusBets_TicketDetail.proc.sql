USE [bodb02]
GO

ALTER PROCEDURE [dbo].[NAP_ColossusBets_TicketDetail]
	@BetId			BIGINT
	,@CustId		INT
AS
/*
Created: 20151012@bobby.nguyen
Task : #44588 - Colossus Bets Payout Management
DB: DBAGE.bodb02
Original:
Revisions:
	- 20151012@bobby.nguyen: Initial
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	SELECT transid, 
		transdate,
		bettype,
		hdp1 AS Sold, 
		(winlost - stake) AS WinLost,
		statusid,
		status
	FROM dbo.bettransm WITH (NOLOCK)
	WHERE custid 	= @CustId
		AND refno 	= @BetId
		AND bettype BETWEEN 18002 AND 18005

	UNION

	SELECT transid, 
		transdate,
		bettype,
		hdp1 AS Sold, 
		(winlost - stake) AS WinLost,
		statusid,
		status
	FROM dbo.bettransm14 WITH (NOLOCK)
	WHERE refno 	= @BetId
		AND bettype BETWEEN 18002 AND 18005
	
	UNION 
	
	SELECT transid, 
		transdate,
		bettype,
		hdp1 AS Sold, 
		(winlost - stake) AS WinLost,
		statusid,
		status
	FROM DBARC.bodb_archive.dbo.bettransm WITH (NOLOCK)
	WHERE refno 	= @BetId
		AND bettype BETWEEN 18002 AND 18005

END
GO
GRANT EXECUTE ON [dbo].[NAP_ColossusBets_TicketDetail] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_ColossusBets_TicketDetail] TO [vnteam] 
