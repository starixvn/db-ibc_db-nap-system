/*<info serverAlias="DBONUSER-ON_USER" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Customer_RobotAccountNew_Sel]
	@username VARCHAR(50) = NULL,		
	@level TINYINT= NULL,
	@site VARCHAR(MAX)= '',
	@currency INT = NULL,
	@counter TINYINT = 0,
	@OrderOption TINYINT = 0,
	@OrderType VARCHAR(10)= 'ASC',
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
			- 20191125@Johnson: change request [redmine:]
		Parameter's Explanation:	
			-@currency = NULL : all currency
			-@counter = 0: all values
					 1: >=10, 2: <10
			-@orderOption: 0 : default 
						1: Currency, 2: Site, 3:Country
						4:Region,5:Last Change Time, 6: Counter	
			-@OrderType = ASC, DESC			
*/ 
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmpCust (custid INT)	
	DECLARE @tmpSite TABLE(site VARCHAR(15))
	DECLARE @RowCount int, @RowStart int, @RowEnd int
	
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 
	
	INSERT INTO @tmpSite(site)
	SELECT val
	FROM bodb02.dbo.strSplit(@site,',')
	
	IF ISNULL(@username,'')= ''
	BEGIN 	
		INSERT INTO #tmpCust(custid)	
		SELECT r.custid
		FROM RobotUsers r WITH(NOLOCK)
			INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.custid = r.custid		
		WHERE roleid = ISNULL(@level,roleid)			
			AND currency = ISNULL(@currency, currency)
			AND ISNULL(r.site,'') IN (SELECT ISNULL(NULLIF(site,'NULL'),'') FROM @tmpSite)
			AND 1 = CASE WHEN @counter = 0 THEN 1
						WHEN @counter = 1 AND counter >= 10 THEN 1
						WHEN @counter = 2 AND ISNULL(counter,0) < 10 THEN 1
					ELSE 0 END
	END
	ELSE 
	BEGIN
		INSERT INTO #tmpCust(custid)	
		SELECT r.custid
		FROM RobotUsers r WITH(NOLOCK)
			INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.custid = r.custid		
		WHERE roleid = ISNULL(@level,roleid)
			AND username = @username
			AND currency = ISNULL(@currency, currency)
			AND ISNULL(r.site,'') IN (SELECT ISNULL(NULLIF(site,'NULL'),'') FROM @tmpSite)
			AND 1 = CASE WHEN @counter = 0 THEN 1
						WHEN @counter = 1 AND counter >= 10 THEN 1
						WHEN @counter = 2 AND ISNULL(counter,0) < 10 THEN 1
					ELSE 0 END
	END
	
	SELECT @totalItems = @@rowcount
	
	DECLARE @sql NVARCHAR(MAX)
						
	SELECT @sql = '
	SELECT custid,currency, username, level, site, IP, country, region, LastChangeTime, counter, serverIP, AddedBy, AddedDate, remark
	FROM (
		SELECT ROW_NUMBER() OVER (' 
		+ CASE @OrderOption 
				WHEN 1 THEN 'ORDER BY ISNULL(r.site,'''') ' + @OrderType + ', c.username ASC, c.roleid DESC, c.custid ASC' 
				WHEN 2 THEN 'ORDER BY e.currency  ' + @OrderType + ', c.username ASC, c.roleid DESC, c.custid ASC' 
				WHEN 3 THEN 'ORDER BY r.country  ' + @OrderType + ', c.username ASC, c.roleid DESC, c.custid ASC' 
				WHEN 4 THEN 'ORDER BY r.region  ' + @OrderType + ', c.username ASC, c.roleid DESC, c.custid ASC' 
				WHEN 5 THEN 'ORDER BY r.LastChangeTime  ' + @OrderType + ', c.username ASC, c.roleid DESC, c.custid ASC' 
				WHEN 6 THEN 'ORDER BY r.counter  ' + @OrderType + ', c.username ASC, c.roleid DESC, c.custid ASC' 
				ELSE ' ORDER BY c.username ASC, c.roleid DESC, c.custid ASC'  END
		+') rn,
			c.custid, e.currency, c.username, CASE c.roleid WHEN 4 THEN ''Super'' WHEN 3 THEN ''Master'' WHEN 2 THEN ''Agent'' WHEN 1 THEN ''Member'' END level,
			ISNULL(r.site,'''') site, r.IP, r.Country, r.Region, r.LastChangeTime, r.counter, r.serverIP, c2.username as AddedBy, r.RobotDate as AddedDate, r.remark
		FROM RobotUsers r WITH(NOLOCK)
			INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.custid = r.custid
			INNER JOIN bodb02.dbo.Exchange e WITH(NOLOCK) ON c.currency = e.exchangeid
			LEFT JOIN bodb02.dbo.customer c2 WITH(NOLOCK) ON c2.custid = r.creator
		WHERE r.custid IN (SELECT custid FROM #tmpCust)
	) t
	WHERE rn BETWEEN '+ CAST(@rowStart AS VARCHAR(10)) +' AND ' + CAST (@rowEnd AS VARCHAR(10)) 
	
	EXEC sys.sp_executesql @sql
END
GO