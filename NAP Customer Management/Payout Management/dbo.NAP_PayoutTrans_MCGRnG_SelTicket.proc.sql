USE [bodb02]
GO

CREATE PROCEDURE [dbo].[NAP_PayoutTrans_SelBetRnGTicket]
	@RefNo		BIGINT,
	@CustId		INT,
	@TransType	TINYINT	= 0
AS
/*
Created: 20151012@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBAGE.bodb02
Original:
Revisions:
	- 20151012@bobby.nguyen: Initial
	
Param's Explanation:
	
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @tmpStatus TABLE (statusId TINYINT)

	IF @TransType = 0
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 111 UNION ALL 
		SELECT 112 UNION ALL 
		SELECT 113 UNION ALL
		SELECT 101 UNION ALL 
		SELECT 102 UNION ALL 
		SELECT 103 UNION ALL 
		SELECT 0 UNION ALL 
		SELECT 1
	END
	ELSE IF @TransType = 1
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 111 UNION ALL 
		SELECT 112 UNION ALL 
		SELECT 113 UNION ALL 
		SELECT 103
	END
	ELSE IF @TransType = 2
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 101 UNION ALL 
		SELECT 102
	END 
	ELSE IF @TransType = 3
	BEGIN
		INSERT INTO @tmpStatus(statusId)
		SELECT 0 UNION ALL 
		SELECT 1
	END

	IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			(brng.winlost - brng.actual_stake) AS WinLost,
			brng.swinlost,
			brng.mwinlost,
			brng.awinlost,
			brng.playercomm AS commission,
			(brng.scomm - brng.acomm) AS scomm,
			(brng.acomm - brng.comm) AS acomm,
			(brng.comm - brng.playercomm) AS comm,
			brng.ip,
			brng.transdesc,
			CASE
				WHEN brng.productID = 205 THEN brng.TranId3rd		-- Microgaming RNG Casino
				ELSE ''
			END AS BetCheck
		FROM dbo.bettransRnG AS brng WITH (NOLOCK)
		WHERE brng.custid = @CustId 
			AND brng.RefNo = @RefNo
			AND brng.statusID IN (SELECT statusId FROM @tmpStatus)
	END
	ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			(brng.winlost - brng.actual_stake) AS WinLost,
			brng.swinlost,
			brng.mwinlost,
			brng.awinlost,
			brng.playercomm AS commission,
			(brng.scomm - brng.acomm) AS scomm,
			(brng.acomm - brng.comm) AS acomm,
			(brng.comm - brng.playercomm) AS comm,
			brng.ip,
			brng.transdesc,
			CASE
				WHEN brng.productID = 205 THEN brng.TranId3rd		-- Microgaming RNG Casino
				ELSE ''
			END AS BetCheck
		FROM dbo.bettransRnG14 AS brng WITH (NOLOCK)
		WHERE brng.custid = @CustId AND brng.RefNo = @RefNo
	END
	ELSE IF EXISTS ( SELECT 1 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			(brng.winlost - brng.actual_stake) AS WinLost,
			brng.swinlost,
			brng.mwinlost,
			brng.awinlost,
			brng.playercomm AS commission,
			(brng.scomm - brng.acomm) AS scomm,
			(brng.acomm - brng.comm) AS acomm,
			(brng.comm - brng.playercomm) AS comm,
			brng.ip,
			brng.transdesc,
			CASE
				WHEN brng.productID = 205 THEN brng.TranId3rd		-- Microgaming RNG Casino
				ELSE ''
			END AS BetCheck
		FROM DBARC.bodb_Archive.dbo.bettransRnG_bk AS brng WITH (NOLOCK)
		WHERE brng.custid = @CustId AND brng.RefNo = @RefNo
	END
		
	RETURN;
	
END
GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_SelBetTicket] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_SelBetTicket] TO [vnteam] 
