ALTER PROCEDURE dbo.NAP_ColossusBets_PayoutList
(
	@UserName		VARCHAR(100)	= ''
	, @BetId		BIGINT			= 0
	, @StatusId		TINYINT			= NULL
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
	
	DECLARE @tblMember 	(custid INT)
	
	DECLARE @tblTrans 	(betId BIGINT)
	
	DECLARE @tblStatus 	(StatusId TINYINT)
	
	
	SELECT @NRows 		= 0
		, @ErrCode 		= 0
		, @ErrMsg 		= ''
		, @offsetRow	= ((@PageIndex-1) + 1)
		, @limitRow		= (@offsetRow + @PageSize)
	
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
			, custid
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
			AND (@StatusId 	IS NULL	OR s.StatusId 	> 0)
	) p
	WHERE p.RowIdx BETWEEN @offsetRow AND @limitRow
		
	SELECT TOP 1 @NRows = TotalRow
	FROM #payoutTicket	
	
	-- Get site name
	DECLARE @custIds 	NVARCHAR(MAX)
		,  @rmtQuery	NVARCHAR(MAX)
		
	SELECT @custIds 	= COALESCE(@custIds + ',', '') + CAST(CustId AS NVARCHAR(15))
	FROM #payoutTicket t
	GROUP BY custId
	
	CREATE TABLE #custSite(CustId INT, SiteName VARCHAR(100))
	
	SET @rmtQuery = N'INSERT INTO #custSite
	SELECT CustId, SiteName
	FROM OPENQUERY([DBCUST], ''SELECT c.CustId, s.site AS SiteName 
		FROM CustDB.dbo.customer c WITH (NOLOCK)	
		INNER JOIN CustDB.dbo.Dep_CustSuper s WITH (NOLOCK)	ON c.srecommend =  s.custid
		WHERE c.roleid = 1 AND c.custid IN (' + ISNULL(@custIds,0) +')''
	)'
	
	
	EXEC sp_executesql @rmtQuery
	
	SELECT c.username
		, c.currency
		, ISNULL(s.SiteName, '-') AS SiteName
		, p.WinAmount
		, p.StatusId
		, p.PayStatus
		, p.PayCode
	FROM dbo.PayoutTrans p WITH(NOLOCK)
		INNER JOIN #payoutTicket t
		ON b.PayoutTransId	= t.BetId
		LEFT JOIN #custSite s 
		ON p.CustId			= s.CustId
		
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[NAP_ColossusBets_PayoutList] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_ColossusBets_PayoutList] TO [bodbAdminNet]
GO
