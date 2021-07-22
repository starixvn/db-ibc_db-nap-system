 /*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
 
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
		- 20161004 Winnie: @Modify to write log when user select smart punters RedmineID: #58901
		- 20181019@Paul: Enhance performance [RedmineID: #103478]
		- 20210505@Tina: Lock account & indirect close account [redmine: #148600]

	Parameter's Explanation:
		@status: 0: all  
				1- open
				2- Suspended
				3- closed					
 */
 BEGIN
	SET NOCOUNT ON 
	
	CREATE TABLE #tmpCust (custid INT PRIMARY KEY, closed BIT, reject BIT)
	DECLARE @RowCount int, @RowStart int, @RowEnd int
	
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 
	
	INSERT INTO #tmpCust(custid, closed, reject)
	SELECT s.custid, ISNULL(cps.closed, cs.closed) closed, ISNULL(cps.reject,cs.reject) reject
	FROM SmartPunterList s WITH(NOLOCK)
		INNER JOIN custinfo ci WITH(NOLOCK) ON s.custid = ci.custid
		OUTER APPLY (
				SELECT TOP 1 custid, isnull(ci.closed,0) closed, isnull(ci.reject,0) reject
				FROM  Dep_CustSuper ds WITH (NOLOCK) 
				WHERE ds.custid = ci.srecommend
			) cs
		OUTER APPLY (
				SELECT TOP 1 ci.custid, 
				CASE WHEN cps.CloseInfo > 0 THEN 1 ELSE 0 END closed, 
				CASE WHEN cps.SuspendInfo > 0 THEN 1 ELSE 0 END reject
				FROM CustProductStatus cps WITH (NOLOCK)
				WHERE cps.CustID = ci.custid
					AND NOT EXISTS (SELECT 1 FROM Dep_CustSuper ds WITH (NOLOCK) WHERE ds.custid = ci.srecommend)
			) cps
		CROSS APPLY (
				SELECT TOP 1 custid, username, username2
				FROM customer c WITH(NOLOCK) 
				WHERE ci.custid = c.custid					
			) c
	WHERE (c.username LIKE @username + '%' OR c.username2 LIKE @username + '%')
		AND 1 = CASE WHEN @status = 0 THEN 1 
						WHEN @status = 1 AND ISNULL(cps.closed, cs.closed) = 0 and ISNULL(cps.reject,cs.reject) = 0 THEN 1
						WHEN @status = 2 AND ISNULL(cps.closed, cs.closed) = 0 and ISNULL(cps.reject,cs.reject) = 1 THEN 1
						WHEN @status = 3 AND ISNULL(cps.closed, cs.closed) = 1 THEN 1 ELSE 0 END
	
	SELECT @totalItems = @@rowcount
	
	SELECT custid, username,roleid
	, username2, closed, reject, e.currency, site, super, t.master, t.agent, t.creator, createdate, remark
	FROM (
		SELECT ROW_NUMBER() OVER(ORDER BY c.username ASC) rn, ci.custid,c.username,c.roleid, c.username2, isnull(tc.closed,0) as closed, isnull(tc.reject,0) as reject, ci.currency,
		CASE WHEN c.roleid=1 THEN ag.site
				ELSE c.site END AS Site, sag.username as super, mag.username as master, ag.username as agent, creator.username as creator, s.createdate, s.remark
		FROM SmartPunterList s WITH(NOLOCK)
			INNER JOIN customer c WITH(NOLOCK) ON s.custid = c.custid
			INNER JOIN custinfo ci WITH(NOLOCK) ON s.custid = ci.custid
			LEFT JOIN customer ag WITH(NOLOCK) ON ci.recommend  = ag.custid 
			LEFT JOIN custinfo mag WITH(NOLOCK) ON ci.mrecommend = mag.custid
			LEFT JOIN custinfo sag WITH(NOLOCK) ON ci.srecommend = sag.custid
			INNER JOIN custinfo creator WITH(NOLOCK) ON s.creator = creator.custid
			INNER JOIN #tmpCust tc ON tc.custid = s.custid
	) t
	INNER JOIN exchange e WITH(NOLOCK) ON e.exchangeid = t.currency
	WHERE t.rn between @RowStart AND @RowEnd
			
						
 END
GO


 