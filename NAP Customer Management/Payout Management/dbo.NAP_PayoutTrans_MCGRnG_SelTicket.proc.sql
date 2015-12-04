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
	- 20151126@bobby.nguyen: Correct time range when selecting ticket tranId3rd info
	
Param's Explanation:
	
*/
BEGIN

	SET NOCOUNT ON
	
	SET @transId3rd = ''
	
	IF (@WinlostDate > @MoveBetsDay)
	BEGIN
		SELECT
			@transId3rd = brng.TranId3rd		-- Microgaming RNG Casino
		FROM bodb02.dbo.bettransRnG AS brng WITH (NOLOCK)
		WHERE brng.custid = @CustId 
			AND brng.transid = @TransId
		
	END
	
	IF(@WinlostDate BETWEEN @BalanceUpDay AND @MoveBetsDay)
	BEGIN
		SELECT
			@transId3rd = brng.TranId3rd		-- Microgaming RNG Casino
		FROM bodb02.dbo.bettransRnG14 AS brng WITH (NOLOCK)
		WHERE brng.custid = @CustId 
			AND brng.transid = @TransId
		
	END
	IF(@WinlostDate < @BalanceUpDay)
	BEGIN
		SELECT
			@transId3rd = brng.TranId3rd		-- Microgaming RNG Casino
		FROM bodb_Archive.dbo.bettransRnG_bk AS brng WITH (NOLOCK)
		WHERE brng.custid = @CustId 
			AND brng.transid = @TransId
	END
		
	RETURN;
	
END

GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_MCGRnG_SelTicket] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_MCGRnG_SelTicket] TO [vnteam] 
