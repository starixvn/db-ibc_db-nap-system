USE bodb02
GO
ALTER PROCEDURE [dbo].[NAP_ColossusBets_PayoutList]
(
	@UserName		VARCHAR(100)	= ''
	, @BetId		BIGINT			= 0
	, @StatusId		TINYINT			= 0
	, @PageIndex	INT				= 1
	, @PageSize		INT				= 1000
	, @NRows 		INT 			= 0 OUTPUT
	, @ErrCode 		INT 			= 0 OUTPUT
	, @ErrMsg 		NVARCHAR(200) 	= '' OUTPUT
)
AS
/*
Created: 20151012@bobby.nguyen
Task : #44588 - Colossus Bets Payout Management
DB: DBTXN.bodb02
Original:
Revisions:
	- 20151012@bobby.nguyen: Initial
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @offsetRow	INT
		, @limitRow		INT
	
	DECLARE @tblMember 	TABLE (custid INT)
	
	DECLARE @tblTrans 	TABLE (betId BIGINT)
	
	DECLARE @tblStatus 	TABLE (StatusId TINYINT)
	
	SELECT @NRows 		= 0
		, @ErrCode 		= 0
		, @ErrMsg 		= ''
		, @offsetRow	= ((@PageIndex-1) + 1)
		, @limitRow		= (@offsetRow + @PageSize)
		, @UserName		= ISNULL(@UserName, '')
		, @BetId		= ISNULL(@BetId, 0)
		, @StatusId		= ISNULL(@StatusId, 0)
	
	-- Search by Member
	IF(@UserName <> '')
	BEGIN
		SELECT @UserName = '%' + @UserName + '%'
		INSERT INTO @tblMember (CustId)		
		SELECT c.custid
		FROM CustDB.dbo.customer c WITH(NOLOCK)
		WHERE c.username 	LIKE @UserName
			AND c.roleid 	= 1
	END
	
	-- Search by BetId
	INSERT INTO @tblTrans ( BetId )
	SELECT @BetId
	WHERE @BetId > 0
	
	-- Search by StatusId
	INSERT INTO @tblStatus ( StatusId )
	SELECT @StatusId
	WHERE @StatusId > 0
	
	SELECT RowIdx
		, BetId
		, CustId
		, TotalRow
	INTO #payoutTicket
	FROM (
		SELECT 
			RowIdx = ROW_NUMBER() OVER ( ORDER BY 
				p.PayoutTransId DESC
			)
			,p.PayoutTransId AS BetId
			, p.custid
			, TotalRow = COUNT(1) OVER()
						
		FROM dbo.PayoutTrans p WITH(NOLOCK)
			LEFT JOIN @tblMember m 	
			ON p.custid 		= m.CustId
			LEFT JOIN @tblTrans t 	
			ON p.PayoutTransId 	= t.BetId
			LEFT JOIN @tblStatus s 	
			ON p.StatusId 		= s.StatusId
		
		WHERE (@UserName 	= '' 	OR m.CustId 	> 0)
			AND (@BetId 	= 0 	OR t.BetId 		> 0)
			AND (@StatusId 	= 0		OR s.StatusId 	> 0)
	) p
	WHERE p.RowIdx BETWEEN @offsetRow AND @limitRow
		
	SELECT TOP 1 @NRows = TotalRow
	FROM #payoutTicket	
	
	-- Get site name
	CREATE TABLE #custSite(CustId INT, UserName VARCHAR(50), Currency INT, CurrencyName VARCHAR(50), SiteName VARCHAR(100))
	;WITH CustTemp AS (
		SELECT CustId
		FROM #payoutTicket t
		GROUP BY custId
	)
	INSERT INTO #custSite
	SELECT c.CustId, c.UserName, c.Currency, e.Currency AS CurrencyName, s.site AS SiteName 
	FROM CustDB.dbo.customer c WITH (NOLOCK)	
		INNER JOIN CustTemp t
		ON c.custid		= t.custid
		INNER JOIN CustDB.dbo.exchange e WITH(NOLOCK)
		ON c.currency 	= e.exchangeid
		LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH (NOLOCK)	
		ON c.srecommend =  s.custid
		
	WHERE c.roleid = 1 
	
	SELECT t.RowIdx 
		, p.PayoutTransId AS BetId 
		, p.CustId
		, s.UserName
		, s.Currency
		, s.CurrencyName
		, ISNULL(s.SiteName, '-') AS SiteName
		, p.WinAmount
		, p.StatusId
		, p.PayStatus
		, p.PayCode
		, ISNULL(n.IsNoted, 0) IsNoted
		
	FROM dbo.PayoutTrans p WITH(NOLOCK)
		INNER JOIN #payoutTicket t
		ON p.PayoutTransId	= t.BetId
		LEFT JOIN #custSite s 
		ON p.CustId			= s.CustId
		OUTER APPLY (
			SELECT TOP 1 CAST(1 AS BIT) AS IsNoted 
			FROM dbo.PayoutDetail d WITH(NOLOCK)
			WHERE PayoutTransId = p.PayoutTransId
		) n
		
	ORDER BY t.RowIdx
	
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[NAP_ColossusBets_PayoutList] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_ColossusBets_PayoutList] TO [vnteam]
GO
