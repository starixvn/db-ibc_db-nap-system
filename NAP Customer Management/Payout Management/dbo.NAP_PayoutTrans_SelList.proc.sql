USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_PayoutTrans_SelList]    Script Date: 11/12/2015 11:39:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_PayoutTrans_SelList]
(
	@UserName			VARCHAR(100)	= ''
	, @PayoutStatusIds	VARCHAR(255) 	= 'ALL'
	, @SiteIds			VARCHAR(1000) 	= 'ALL'
	, @ProductIds		VARCHAR(1000) 	= 'ALL'
	, @FromDate			DATE			= NULL
	, @ToDate			DATE			= NULL
	, @PageIndex		INT				= 1
	, @PageSize			INT				= 1000
	, @NRows 			INT 			= 0 OUTPUT
	, @ErrCode 			INT 			= 0 OUTPUT
	, @ErrMsg 			NVARCHAR(255) 	= '' OUTPUT
)
AS
/*
Created: 20151012@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBEXT.bodb02
Original:
Revisions:
	- 20151012@bobby.nguyen: Initial
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @curDate	DATE 
		, @offsetRow	INT
		, @limitRow		INT
	
	CREATE TABLE #tblSite 	(siteid INT)
	CREATE TABLE #tblProduct(productid SMALLINT)
	
	CREATE TABLE #payoutTrans ( 
		RowIdx			INT
		, PayoutTransId INT 
		, custid		INT
		, TotalRow		INT
	)
	
	SELECT @NRows 		= 0
		, @ErrCode 		= 0
		, @ErrMsg 		= ''
		, @offsetRow	= ((@PageIndex-1) + 1)
		, @limitRow		= (@offsetRow + @PageSize)
		, @UserName		= ISNULL(@UserName, '')
		, @curDate		= GETDATE()
		
	SELECT
		@PayoutStatusIds= ISNULL(@PayoutStatusIds, 'ALL')
		,@SiteIds 		= ISNULL(@SiteIds, 'ALL')
		,@ProductIds 	= ISNULL(@ProductIds, 'ALL')
	
	SELECT @FromDate	= ISNULL(@FromDate, CONVERT(DATE, CAST(YEAR(@curDate) AS VARCHAR(5)) + '0101'))
		, @ToDate		= ISNULL(@ToDate, @curDate)
	
	DECLARE @execQuery	NVARCHAR(MAX)
		, @selQuery 	NVARCHAR(MAX)
		, @whereQuery 	NVARCHAR(MAX)
	
	SELECT @selQuery		= '
			INSERT INTO #payoutTrans
			SELECT 
				RowIdx = ROW_NUMBER() OVER ( ORDER BY 
					p.PayoutTransId DESC
				)
				, p.PayoutTransId
				, p.custid
				, TotalRow = COUNT(1) OVER()
							
			FROM bodb02.dbo.PayoutTrans p WITH(NOLOCK)'
			, @whereQuery		= '
			WHERE p.WinlostDate BETWEEN ''' + CAST(@FromDate AS VARCHAR(15)) + ''' AND '''  + CAST(@ToDate AS VARCHAR(15)) + ''''
		
	IF(@SiteIds <> 'ALL')
	BEGIN
		SELECT @selQuery	+= '
				INNER JOIN dbo.Customer c WITH(NOLOCK)
				ON p.custId 	= c.custId
				INNER JOIN bodb02.dbo.Customer rec WITH(NOLOCK)
				ON c.recommend 	= rec.custId
				INNER JOIN bodb02.dbo.[site] s WITH(NOLOCK)
				ON rec.[site] 	= s.[site]'
			, @whereQuery	+= '
				AND s.[siteid] IN (' + @SiteIds + ')'
			
	END
	
	IF(@ProductIds <> 'ALL')
	BEGIN
		SELECT @whereQuery	+= '
				AND p.ProductId IN (' + @ProductIds + ')'
	END
	
	-- Search by Member
	IF(@UserName <> '')
	BEGIN
		SELECT @UserName 		=  '%' + @UserName + '%'
			, @whereQuery		+= ' 
				AND p.UserName LIKE ''' + @UserName + ''''
	END
	
	IF (@PayoutStatusIds <> 'ALL')
	BEGIN
		SELECT @whereQuery		+= ' 
				AND p.PayoutStatusId IN (' + @PayoutStatusIds + ')'
	END
	
	SET @execQuery = @selQuery + @whereQuery

	EXEC sp_executesql @execQuery

	
	SELECT RowIdx
		, PayoutTransId
		, CustId
		, TotalRow
	INTO #payoutPaging
	FROM #payoutTrans p
	WHERE p.RowIdx BETWEEN @offsetRow AND @limitRow
		
	SELECT TOP 1 @NRows = TotalRow
	FROM #payoutPaging
	
	-- Get site name
	CREATE TABLE #custSite(CustId INT, UserName VARCHAR(50), Currency INT, CurrencyName VARCHAR(50), SiteName VARCHAR(100))
	;WITH CustTemp AS (
		SELECT CustId
		FROM #payoutPaging t
		GROUP BY custId
	)
	INSERT INTO #custSite
	SELECT c.CustId, c.UserName, c.Currency, e.Currency AS CurrencyName, r.site AS SiteName 
	FROM bodb02.dbo.customer c WITH (NOLOCK)	
		INNER JOIN CustTemp t
		ON c.custid		= t.custid
		INNER JOIN bodb02.dbo.exchange e WITH(NOLOCK)
		ON c.currency 	= e.exchangeid
		INNER JOIN bodb02.dbo.customer r WITH (NOLOCK)	
		ON c.recommend =  r.custid
		
	WHERE c.roleid = 1 
	
	SELECT t.RowIdx 
		, t.PayoutTransId
		, p.RefNo
		, p.CustId
		, s.UserName
		, s.Currency
		, s.CurrencyName
		, ISNULL(s.SiteName, '-') AS SiteName
		, p.WinlostDate
		, p.ProductId
		, sp.SportName AS ProductName
		, p.WinAmount
		, p.PayoutStatusId
		, p.PayoutStatus
		, p.PayoutCode
		, ISNULL(n.IsNoted, 0) IsNoted
		
	FROM bodb02.dbo.PayoutTrans p WITH(NOLOCK)
		INNER JOIN bodb02.dbo.[f_ProductPayout] () sp
		ON p.ProductId	= sp.SportType
		INNER JOIN #payoutPaging t
		ON p.PayoutTransId	= t.PayoutTransId
		LEFT JOIN #custSite s 
		ON p.CustId			= s.CustId
		OUTER APPLY (
			SELECT TOP 1 CAST(1 AS BIT) AS IsNoted 
			FROM [bodb_CustomerLog].dbo.PayoutDetail d WITH(NOLOCK)
			WHERE d.PayoutTransId = p.PayoutTransId
		) n
		
	ORDER BY t.RowIdx
	
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_SelList] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_SelList] TO [vnteam]
GO
