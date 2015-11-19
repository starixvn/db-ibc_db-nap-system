USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_PayoutTrans_SelBetTicket]    Script Date: 11/12/2015 11:40:39 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[NAP_PayoutTrans_SelBetTicket]
	@PayoutTransId	INT = 0
	,@CustId		INT = 0
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
	
	DECLARE @transId3rd		NVARCHAR(64)
		, @RefNo			BIGINT
		, @WinlostDate		SMALLDATETIME
		, @WinAmount		MONEY
		, @ProductId		SMALLINT
		, @ProductName		VARCHAR(50)
		, @SiteName			VARCHAR(100)
	
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
		, @SiteName		= r.[site]
	FROM bodb02.dbo.PayoutTrans p WITH(NOLOCK)
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK)
		ON p.custid		= c.custid
		INNER JOIN bodb02.dbo.customer r WITH(NOLOCK)
		ON c.recommend	= r.custid
		LEFT JOIN bodb02.dbo.[f_ProductPayout]() s
		ON p.ProductId		= s.SportType
	WHERE p.PayoutTransId 	= @PayoutTransId
		AND p.CustId		= @CustId
	
	/*
		ProductId
		204: Colossus Bets
		205: Microgaming RNG Casino
	*/
	IF(@ProductId IN (204))
	BEGIN
		EXEC bodb02.[dbo].[NAP_PayoutTrans_ColossusBets_SelTicket]
		@RefNo			= @RefNo,
		@CustId			= @CustId,
		@WinlostDate	= @WinlostDate, 
		@MoveBetsDay	= @MoveBetsDay,
		@BalanceUpDay	= @BalanceUpDay,
		@transId3rd		= @transId3rd OUTPUT
	END
	IF(@ProductId IN (203,205))
	BEGIN
		EXEC bodb02.[dbo].[NAP_PayoutTrans_MCGRnG_SelTicket]
		@TransId		= @RefNo,
		@CustId			= @CustId,
		@WinlostDate	= @WinlostDate, 
		@MoveBetsDay	= @MoveBetsDay,
		@BalanceUpDay	= @BalanceUpDay,
		@transId3rd		= @transId3rd OUTPUT
	END
	
	SELECT 
		@CustId			AS CustId
		, @RefNo 		AS RefNo
		, @ProductId 	AS ProductId
		, @ProductName	AS ProductName
		, @WinlostDate 	AS WinlostDate
		, @WinAmount 	AS WinAmount
		, @transId3rd	AS TransId3rd
		, @SiteName		AS SiteName
		
	RETURN;
	
END
GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_SelBetTicket] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_SelBetTicket] TO [vnteam] 
GO