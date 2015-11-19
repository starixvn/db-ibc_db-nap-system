USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_PayoutTrans_MCGRnG_SelTicket]    Script Date: 11/12/2015 11:41:41 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[NAP_PayoutTrans_MCGRnG_SelTicket]
	@TransId		BIGINT,
	@CustId			INT,
	@TransType		TINYINT = 0,
	@WinlostDate	SMALLDATETIME, 
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@transId3rd		NVARCHAR(64) = '' OUTPUT
AS
/*
Created: 20151012@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBACC.bodb02
Original:
Revisions:
	- 20151012@bobby.nguyen: Initial
	
Param's Explanation:
	
*/
BEGIN

	SET NOCOUNT ON
	
	/*
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
	*/
	
	SET @transId3rd = ''
	
	IF (@WinlostDate > @MoveBetsDay)
	BEGIN
		SELECT
			@transId3rd = brng.TranId3rd		-- Microgaming RNG Casino
		FROM bodb02.dbo.bettransRnG AS brng WITH (NOLOCK)
		WHERE brng.custid = @CustId 
			AND brng.transid = @TransId
		/*	
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
		*/
	END
	
	IF(@WinlostDate BETWEEN @MoveBetsDay AND @BalanceUpDay)
	BEGIN
		SELECT
			@transId3rd = brng.TranId3rd		-- Microgaming RNG Casino
		FROM bodb02.dbo.bettransRnG14 AS brng WITH (NOLOCK)
		WHERE brng.custid = @CustId 
			AND brng.transid = @TransId
		/*
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
		*/
	END
	IF(@WinlostDate < @BalanceUpDay)
	BEGIN
		SELECT
			@transId3rd = brng.TranId3rd		-- Microgaming RNG Casino
		FROM bodb_Archive.dbo.bettransRnG_bk AS brng WITH (NOLOCK)
		WHERE brng.custid = @CustId 
			AND brng.transid = @TransId
		/*
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
		*/
	END
		
	RETURN;
	
END

GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_MCGRnG_SelTicket] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_MCGRnG_SelTicket] TO [vnteam] 
