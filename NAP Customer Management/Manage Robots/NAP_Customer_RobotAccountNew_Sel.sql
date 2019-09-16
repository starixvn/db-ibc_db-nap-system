/*<info serverAlias="DBONUSER-ON_USER" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_Customer_RobotAccountNew_Sel]
	@username VARCHAR(50) = NULL,		
	@level TINYINT= NULL,
	@site VARCHAR(10)= NULL,
	@pageIndex	INT = 1,
	@pageSize	INT = 50,
	@totalItems INT = 0 OUTPUT	
AS
/*
		Created: Johnson
		Date: 2019-09-12
		Task: select robot accounts new version
		DB: DBONUSER/ON_USER
		
		Revision:
			- 20190912@Johnson: Initial sp [redmine:#119714]
		Parameter's Explanation:			
*/ 
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowCount int, @RowStart int, @RowEnd int
	
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 
	
	INSERT INTO @tmpCust(custid)	
	SELECT r.custid
	FROM RobotUsers r WITH(NOLOCK)
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.custid = r.custid		
	WHERE roleid = ISNULL(@level,roleid)
		AND username LIKE ISNULL(@username,username)
		AND site = ISNULL(@site,site)
	
	SELECT @totalItems = @@rowcount
	
	SELECT custid, username, level, site, LastChangeTime, counter, serverIP, AddedBy, AddedDate, remark
	FROM (
		SELECT ROW_NUMBER() OVER (ORDER BY username ASC, roleid DESC, c.custid ASC) rn,
			c.custid, c.username, CASE c.roleid WHEN 4 THEN 'Super' WHEN 3 THEN 'Master' WHEN 2 THEN 'Agent' WHEN 1 THEN 'Member' END level,
			r.site, r.IP, r.LastChangeTime,	r.counter, r.serverIP, r.AddedBy, r.RobotDate as AddedDate, r.remark
		FROM RobotUsers r WITH(NOLOCK)
			INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.custid = r.custid
		WHERE r.custid IN (SELECT custid FROM @tmpCust)
	) t
	WHERE rn BETWEEN @rowStart AND @rowEnd
	
END
GO