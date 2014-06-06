  ALTER PROCEDURE [dbo].[NAP_CustomerSelRobotAccounts]
	 @username VARCHAR(50) = '',
	 @status	BIT = NULL,
	 @pageIndex	INT = 1,
	 @pageSize	INT = 50,
	 @totalItems INT = 0 OUTPUT
 AS
 /*
	Created: Johnson
	Date: 2014-05-30
	Task: Get list robot accounts
	DB: DBTXN/CustDB
	
	Parameter's Explanation:
		- @stautus : 1 Active
					0 In-active
					Null All
 */
 BEGIN 
	SET NOCOUNT ON
	
	DECLARE @tmpCust TABLE (custid INT PRIMARY KEY)
	DECLARE @RowCount int, @RowStart int, @RowEnd int
	
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 
	
	INSERT INTO @tmpCust(custid)
	SELECT r.custid
	FROM RobotList_tmp r WITH(NOLOCK)
		INNER JOIN customer c WITH(NOLOCK) ON r.custid = c.custid
	WHERE c.username LIKE @username + '%'
		AND isactive = ISNULL(@status,isActive)
		
	SELECT @totalItems = @@rowcount
	
	SELECT custid, username, t.isActive, e.currency, site, t.super, t.master, t.agent, t.creator, createdate, modifyuser, lastmodifytime,  remark
	FROM (
			SELECT ROW_NUMBER() OVER (ORDER BY isActive DESC, c.username ASC) rn, c.custid, c.username, isActive, c.currency, ag.site, ag.username as agent, mag.username as master, sag.username as super, creator.username as creator, r.createdate, m.username as modifyuser, r.lastmodifytime, r.remark
			FROM RobotList_tmp r WITH(NOLOCK)
				INNER JOIN customer c WITH(NOLOCK) ON r.custid = c.custid
				LEFT JOIN custinfo creator WITH(NOLOCK) ON r.creator = creator.custid
				LEFT JOIN custinfo m WITH(NOLOCK) ON r.lastmodifyuser = m.custid
				INNER JOIN customer ag WITH(NOLOCK) ON c.recommend = ag.custid
				INNER JOIN custinfo mag WITH(NOLOCK) ON c.mrecommend = mag.custid
				INNER JOIN custinfo sag WITH(NOLOCK) ON c.srecommend = sag.custid
			WHERE r.custid IN (SELECT custid FROM @tmpCust)		
		) t
		INNER JOIN exchange e WITH(NOLOCK) ON t.currency = e.exchangeid
	WHERE t.rn between @RowStart and @RowEnd
	
	
END


GO

GRANT EXECUTE ON [dbo].[NAP_CustomerSelRobotAccounts] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[NAP_CustomerSelRobotAccounts] TO [vnteam] AS [dbo]
GO


