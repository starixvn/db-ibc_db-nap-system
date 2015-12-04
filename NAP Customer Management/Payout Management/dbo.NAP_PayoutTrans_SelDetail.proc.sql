USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_PayoutTrans_SelDetail]    Script Date: 11/12/2015 11:40:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_PayoutTrans_SelDetail]
(
	@PayoutTransId		INT = 0
)
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
	SET NOCOUNT ON;
	
	DECLARE @transId3rd		NVARCHAR(64)
		, @CustId			INT
		, @RefNo			BIGINT
		, @WinlostDate		SMALLDATETIME
		, @ProductId		SMALLINT
	
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
		p.CustId
		, p.UserName
		, p.RefNo
		, p.ProductId
		, p.WinlostDate
		, p.WinAmount
		, p.PayoutCode
		, c.Currency
		, e.Currency AS CurrencyName
		, r.site AS SiteName 
	INTO #payoutTrans
	FROM bodb02.dbo.PayoutTrans p WITH(NOLOCK)
		INNER JOIN bodb02.dbo.customer c WITH (NOLOCK)	
		ON p.custid 	= c.custid
		INNER JOIN bodb02.dbo.exchange e WITH(NOLOCK)
		ON c.currency 	= e.exchangeid
		INNER JOIN bodb02.dbo.customer r WITH (NOLOCK)	
		ON c.recommend 	=  r.custid
	WHERE p.PayoutTransId 	= @PayoutTransId
	
	SELECT @WinlostDate = WinlostDate
		, @CustId		= CustId
		, @RefNo		= RefNo
		, @ProductId	= ProductId
	FROM #payoutTrans
	/*
		ProductId
		204: Collosus Bets
		205: Microgaming RNG Casino
	*/
	IF(@WinlostDate > @MoveBetsDay )
	BEGIN
		IF(@ProductId IN (203,205))
		BEGIN
			SELECT @transId3rd	= b.TranId3rd
			FROM bodb02.dbo.BettransRnG b WITH(NOLOCK)
			WHERE b.transid 	= @RefNo
				AND b.CustId	= @CustId
		END
		
		IF(@ProductId IN (204))
		BEGIN
			SELECT @transId3rd	= b.betcheck
			FROM bodb02.dbo.Bettransm b WITH(NOLOCK)
			WHERE b.refno 		= @RefNo
				AND b.bettype	= 18001
				AND b.CustId	= @CustId
		END
	END
	
	IF(@WinlostDate BETWEEN @BalanceUpDay AND @MoveBetsDay)
	BEGIN
		IF(@ProductId IN (203,205))
		BEGIN
			SELECT @transId3rd	= b.TranId3rd
			FROM bodb02.dbo.BettransRnG14 b WITH(NOLOCK)
			WHERE b.transid 	= @RefNo
				AND b.CustId	= @CustId
		END
		
		IF(@ProductId IN (204))
		BEGIN
			SELECT @transId3rd	= b.betcheck
			FROM bodb02.dbo.Bettransm14 b WITH(NOLOCK)
			WHERE b.refno 		= @RefNo
				AND b.bettype	= 18001
				AND b.CustId	= @CustId
		END
	END
	
	IF(@WinlostDate < @BalanceUpDay)
	BEGIN
		IF(@ProductId IN (203,205))
		BEGIN
			SELECT @transId3rd	= b.TranId3rd
			FROM [bodb_archive].dbo.BettransRnG_bk b WITH(NOLOCK)
			WHERE b.transid 	= @RefNo
				AND b.CustId	= @CustId
		END
		
		IF(@ProductId IN (204))
		BEGIN
			SELECT @transId3rd	= b.betcheck
			FROM [bodb_archive].dbo.Bettransm b WITH(NOLOCK)
			WHERE b.refno 		= @RefNo
				AND b.bettype	= 18001
				AND b.CustId	= @CustId
		END
	END
	
	SELECT 
		p.*
		, @transId3rd	AS TransId3rd
	FROM #payoutTrans p
	
	-- SELECT payout trans detail in status
	SELECT d.CreatedDate
		, ISNULL(c.UserName, '-') AS UserName
		, d.PayoutStatusId
		, d.PayoutStatus
		, d.PayoutNote
		, d.IP
		
	FROM [DBLOG].[bodb_CustomerLog].dbo.PayoutDetail d WITH(NOLOCK)
		LEFT JOIN bodb02.dbo.customer c WITH(NOLOCK)
		ON d.Creator = c.custid
	WHERE d.PayoutTransId = @PayoutTransId
		
	ORDER BY d.CreatedDate DESC
	
	RETURN;
END

GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_SelDetail] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_SelDetail] TO [vnteam]
GO