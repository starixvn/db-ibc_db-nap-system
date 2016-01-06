USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_PayoutTrans_ColossusBets_SelTicket]    Script Date: 11/12/2015 11:42:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[NAP_PayoutTrans_ColossusBets_SelTicket]
	@RefNo			BIGINT,
	@CustId			INT,
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
	- 20160106@bobby.nguyen: #50364 - Update for CB change request
	
Param's Explanation:
	
*/
BEGIN

	SET NOCOUNT ON
	
	DECLARE @bettransRefno	BIGINT
	
	SET @transId3rd	= ''
		
	IF(@WinlostDate > @MoveBetsDay )
	BEGIN
		SELECT @bettransRefno = refno
		FROM bodb02.dbo.bettrans (NOLOCK) 
		WHERE transid = @RefNo
		
		SELECT @transId3rd	= b.betcheck
		FROM bodb02.dbo.Bettransm b WITH(NOLOCK)
		WHERE b.refno 		= @bettransRefno
			AND b.bettype	= 18001
			AND b.CustId	= @CustId
			
		SELECT transid, 
			transdate,
			bettype,
			hdp1 AS Sold, 
			(winlost - stake) AS WinLost,
			statusid,
			status
			--,@transId3rd AS TransId3rd
		FROM bodb02.dbo.bettransm WITH (NOLOCK)
		WHERE custid 	= @CustId
			AND refno 	= @bettransRefno
			AND bettype BETWEEN 18002 AND 18005
		
	END
	
	IF(@WinlostDate BETWEEN @BalanceUpDay AND @MoveBetsDay)
	BEGIN
		SELECT @bettransRefno = refno
		FROM bodb02.dbo.bettrans14 (NOLOCK) 
		WHERE transid = @RefNo
		
		SELECT @transId3rd	= b.betcheck
		FROM bodb02.dbo.Bettransm14 b WITH(NOLOCK)
		WHERE b.refno 		= @bettransRefno
			AND b.bettype	= 18001
			AND b.CustId	= @CustId
			
		SELECT transid, 
			transdate,
			bettype,
			hdp1 AS Sold, 
			(winlost - stake) AS WinLost,
			statusid,
			status
			--,@transId3rd AS TransId3rd
		FROM bodb02.dbo.bettransm14 WITH (NOLOCK)
		WHERE refno 	= @bettransRefno
			AND bettype BETWEEN 18002 AND 18005
		
	END
	IF(@WinlostDate < @BalanceUpDay)
	BEGIN
		
		SELECT @bettransRefno = refno
		FROM bodb_archive.dbo.bettrans_bk (NOLOCK) 
		WHERE transid = @RefNo
		
		SELECT @transId3rd	= b.betcheck
		FROM bodb_archive.dbo.bettransm b WITH (NOLOCK)
		WHERE b.refno 		= @bettransRefno
			AND b.bettype	= 18001
			AND b.CustId	= @CustId
			
		SELECT transid, 
			transdate,
			bettype,
			hdp1 AS Sold, 
			(winlost - stake) AS WinLost,
			statusid,
			status
			--,@transId3rd AS TransId3rd
		FROM bodb_archive.dbo.bettransm b WITH (NOLOCK)
		WHERE refno 	= @bettransRefno
			AND bettype BETWEEN 18002 AND 18005
		
	END
		
	RETURN;
	
END
GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_ColossusBets_SelTicket] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_ColossusBets_SelTicket] TO [vnteam] 
