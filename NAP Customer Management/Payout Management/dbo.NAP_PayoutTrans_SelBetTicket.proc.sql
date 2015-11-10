USE [bodb02]
GO

CREATE PROCEDURE [dbo].[NAP_PayoutTrans_SelBetTicket]
	@PayoutTransId	INT = 0
	,@CustId		INT = 0
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
	
	DECLARE @transId3rd		NVARCHAR(64)
		, @RefNo			BIGINT
		, @WinlostDate		SMALLDATETIME
		, @WinAmount		MONEY
		, @ProductId		SMALLINT
		, @ProductName		SMALLINT
	
	DECLARE @MoveBetsDay 	SMALLDATETIME
		, @BalanceUpDay 	SMALLDATETIME

	DECLARE @tmpDate		TABLE (	
		BalanceUpDay 		SMALLDATETIME
		, MoveBetsDay 		SMALLDATETIME
	) 
	INSERT INTO @tmpDate(BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT @MoveBetsDay 	= MoveBetsDay
		, @BalanceUpDay 	= BalanceUpDay 
	FROM @tmpDate

	

	-- PayoutTrans - main ticket
	SELECT TOP(1)
		 @RefNo 		= p.RefNo
		, @ProductId 	= p.ProductId
		, @ProductName	= s.SportName
		, @WinlostDate 	= p.WinlostDate
		, @WinAmount 	= p.WinAmount
		
	FROM bodb02.dbo.PayoutTrans p WITH(NOLOCK)
		LEFT JOIN dbo.Sports s
		ON p.ProductId		= s.SportType
	WHERE p.PayoutTransId 	= @PayoutTransId
		AND p.CustId		= @CustId
	
	/*
		ProductId
		204: Collosus Bets
		205: Microgaming RNG Casino
	*/
	IF(@WinlostDate > @MoveBetsDay )
	BEGIN
		IF(@ProductId IN (204))
		BEGIN
			SELECT @transId3rd	= b.betcheck
			FROM dbo.Bettransm b WITH(NOLOCK)
			WHERE b.refno 		= @RefNo
				AND b.bettype	= 18001
				AND b.CustId	= @CustId
				
			SELECT transid, 
				transdate,
				bettype,
				hdp1 AS Sold, 
				(winlost - stake) AS WinLost,
				statusid,
				status
			FROM dbo.bettransm WITH (NOLOCK)
			WHERE custid 	= @CustId
				AND refno 	= @RefNo
				AND bettype BETWEEN 18002 AND 18005
		END
	END
	
	IF(@WinlostDate BETWEEN @MoveBetsDay AND @BalanceUpDay)
	BEGIN
		IF(@ProductId IN (204))
		BEGIN
			SELECT @transId3rd	= b.betcheck
			FROM dbo.Bettransm14 b WITH(NOLOCK)
			WHERE b.refno 		= @RefNo
				AND b.bettype	= 18001
				AND b.CustId	= @CustId
				
			SELECT transid, 
				transdate,
				bettype,
				hdp1 AS Sold, 
				(winlost - stake) AS WinLost,
				statusid,
				status
			FROM dbo.bettransm14 WITH (NOLOCK)
			WHERE refno 	= @RefNo
				AND bettype BETWEEN 18002 AND 18005
		END
	END
	IF(@WinlostDate > @BalanceUpDay)
	BEGIN
		IF(@ProductId IN (204))
		BEGIN
			SELECT @transId3rd	= b.betcheck
			FROM DBARC.bodb_archive.dbo.bettransm b WITH (NOLOCK)
			WHERE b.refno 		= @RefNo
				AND b.bettype	= 18001
				AND b.CustId	= @CustId
				
			SELECT transid, 
				transdate,
				bettype,
				hdp1 AS Sold, 
				(winlost - stake) AS WinLost,
				statusid,
				status
			FROM DBARC.bodb_archive.dbo.bettransm b WITH (NOLOCK)
			WHERE refno 	= @RefNo
				AND bettype BETWEEN 18002 AND 18005
		END
	END
	
	SELECT 
		@CustId			AS CustId
		, @RefNo 		AS RefNo
		, @ProductId 	AS ProductId
		, @ProductName	AS ProductName
		, @WinlostDate 	AS WinlostDate
		, @WinAmount 	AS WinAmount
		, @transId3rd	AS TransId3rd
		
	RETURN;
	
END
GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_SelBetTicket] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_SelBetTicket] TO [vnteam] 
