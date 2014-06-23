 ALTER PROCEDURE [dbo].[NAP_CustomerSelSmartPunter]
	@username VARCHAR(50)= '',
	@status	 TINYINT = 0,
	@pageIndex	INT = 1,
	@pageSize	INT = 50,
	@totalItems INT = 0 OUTPUT
 AS
 /*
	Created: Johnson
	Date: 2014-06-10
	Task: Get smart punters list
	DB: DBACC/bodb02
	
	Revisions:
	
	Parameter's Explanation:
		@status: 0: all  
				1- open
				2- Suspended
				3- closed					
 */
 BEGIN
	SET NOCOUNT ON 
	
	CREATE TABLE #tmpCust (custid INT PRIMARY KEY)
	DECLARE @RowCount int, @RowStart int, @RowEnd int
	
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 
	
	INSERT INTO #tmpCust
	SELECT s.custid
	FROM SmartPunterList s WITH(NOLOCK)
		INNER JOIN customer c WITH(NOLOCK) ON s.custid = c.custid
		INNER JOIN custinfo ci WITH(NOLOCK) ON s.custid = ci.custid
	WHERE (c.username LIKE @username + '%' OR c.username2 LIKE @username + '%')
		AND 1 = CASE WHEN @status = 0 THEN 1 
					WHEN @status = 1 AND isnull(closed,0) = 0 and isnull(reject,0) = 0 THEN 1
					WHEN @status = 2 AND isnull(closed,0) = 0 and isnull(reject,0) = 1 THEN 1
					WHEN @status = 3 AND isnull(closed,0) = 1 THEN 1 ELSE 0 END
	
	SELECT @totalItems = @@rowcount
	
	SELECT custid, username, username2, closed, reject, e.currency, site, super, t.master, t.agent, t.creator, createdate, remark
	FROM (
		SELECT ROW_NUMBER() OVER(ORDER BY c.username ASC) rn, c.custid, c.username, c.username2, isnull(ci.closed,0) as closed, isnull(ci.reject,0) as reject, ci.currency, ag.site, sag.username as super, mag.username as master, ag.username as agent, creator.username as creator, s.createdate, s.remark
		FROM SmartPunterList s WITH(NOLOCK)
			INNER JOIN customer c WITH(NOLOCK) ON s.custid = c.custid
			INNER JOIN custinfo ci WITH(NOLOCK) ON s.custid = ci.custid
			INNER JOIN customer ag WITH(NOLOCK) ON ci.recommend = ag.custid
			INNER JOIN custinfo mag WITH(NOLOCK) ON ci.mrecommend = mag.custid
			INNER JOIN custinfo sag WITH(NOLOCK) ON ci.srecommend = sag.custid
			INNER JOIN custinfo creator WITH(NOLOCK) ON s.creator = creator.custid
		WHERE s.custid IN (SELECT custid FROM #tmpCust)
	) t
	INNER JOIN exchange e WITH(NOLOCK) ON e.exchangeid = t.currency
	WHERE t.rn between @RowStart AND @RowEnd
			
						
 END
 GO
 
 GRANT EXECUTE ON [dbo].[NAP_CustomerSelSmartPunter] TO [bodbAdminNet]
 