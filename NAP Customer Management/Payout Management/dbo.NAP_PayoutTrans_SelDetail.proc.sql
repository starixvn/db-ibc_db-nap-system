USE bodb02
GO
ALTER PROCEDURE [dbo].[NAP_PayoutTrans_SelDetail]
(
	@PayoutTransId		INT = 0
)
AS
/*
Created: 20151012@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBTXN.bodb02
Original:
Revisions:
	- 20151012@bobby.nguyen: Initial
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @transId3rd		NVARCHAR(64)
		, @CustId			INT
		, @RefNo			BIGINT
		, @PayoutCode		NVARCHAR(250)
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
		@CustId			= p.CustId
		, @RefNo 		= p.RefNo
		, @ProductId 	= p.ProductId
		, @ProductName	= s.SportName
		, @WinlostDate 	= p.WinlostDate
		, @WinAmount 	= p.WinAmount
		, @PayoutCode 	= p.PayoutCode
		
	FROM bodb02.dbo.PayoutTrans p WITH(NOLOCK)
		LEFT JOIN dbo.Sports s
		ON p.ProductId		= s.SportType
	WHERE p.PayoutTransId 	= @PayoutTransId
	
	/*
		ProductId
		204: Collosus Bets
		205: Microgaming RNG Casino
	*/
	IF(@WinlostDate > @MoveBetsDay )
	BEGIN
		IF(@ProductId IN (205))
		BEGIN
			SELECT @transId3rd	= b.TranId3rd
			FROM dbo.BettransRnG b WITH(NOLOCK)
			WHERE b.transid 	= @RefNo
				AND b.CustId	= @CustId
		END
		
		IF(@ProductId IN (204))
		BEGIN
			SELECT @transId3rd	= b.betcheck
			FROM dbo.Bettransm b WITH(NOLOCK)
			WHERE b.refno 		= @RefNo
				AND b.bettype	= 18001
				AND b.CustId	= @CustId
		END
	END
	
	IF(@WinlostDate BETWEEN @MoveBetsDay AND @BalanceUpDay)
	BEGIN
		IF(@ProductId IN (205))
		BEGIN
			SELECT @transId3rd	= b.TranId3rd
			FROM dbo.BettransRnG14 b WITH(NOLOCK)
			WHERE b.transid 	= @RefNo
				AND b.CustId	= @CustId
		END
		
		IF(@ProductId IN (204))
		BEGIN
			SELECT @transId3rd	= b.betcheck
			FROM dbo.Bettransm14 b WITH(NOLOCK)
			WHERE b.refno 		= @RefNo
				AND b.bettype	= 18001
				AND b.CustId	= @CustId
		END
	END
	
	IF(@WinlostDate < @BalanceUpDay)
	BEGIN
		--IF(@ProductId IN (205))
		--BEGIN
		--	SELECT @transId3rd	= b.TranId3rd
		--	FROM [DBARC].[bodb_archive].dbo.BettransRnG b WITH(NOLOCK)
		--	WHERE b.transid 	= @RefNo
		--		AND b.CustId	= @CustId
		--END
		
		IF(@ProductId IN (204))
		BEGIN
			SELECT @transId3rd	= b.betcheck
			FROM [DBARC].[bodb_archive].dbo.Bettransm b WITH(NOLOCK)
			WHERE b.refno 		= @RefNo
				AND b.bettype	= 18001
				AND b.CustId	= @CustId
		END
	END
	
	SELECT 
		@CustId			AS CustId
		, @RefNo 		AS RefNo
		, @ProductId 	AS ProductId
		, @ProductName	AS ProductName
		, @WinlostDate 	AS WinlostDate
		, @WinAmount 	AS WinAmount
		, @PayoutCode 	AS PayoutCode
		, @transId3rd	AS TransId3rd
	
	-- SELECT payout trans detail in status
	SELECT d.CreatedDate
		, ISNULL(c.UserName, '-') AS UserName
		, d.PayoutStatusId
		, d.PayoutStatus
		, d.PayoutNote
		, d.IP
		
	FROM [bodb_CustomerLog].dbo.PayoutDetail d WITH(NOLOCK)
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
exec [NAP_PayoutTrans_SelDetail]