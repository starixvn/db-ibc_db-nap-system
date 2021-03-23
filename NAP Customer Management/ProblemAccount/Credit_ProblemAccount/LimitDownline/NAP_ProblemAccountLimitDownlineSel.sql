/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_ProblemAccountLimitDownlineSel]
	@username 	VARCHAR(50) = '',
	@level 	  	TINYINT = 0,
	@site		VARCHAR(MAX) = '',
	@PageSize	INT = 100,
	@PageIndex	INT = 1,
	@TotalItems	INT = 0 OUTPUT
	
AS
/*
	Created: 20210303@Johnson
	Task : get list problem account limit downline config for credit site
	DB: DBCUST/CustDB

	Revisions:
		- 20210303@Johnson: Initial SP [Redmine:#149477]		
	Parameter's explaination: 		
		- @level = 0: all; 2,3,4: SMA
		- @site  = sitename
	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RowStart INT,
			@RowEnd INT
	
	DECLARE @tmpSite TABLE (site VARCHAR(30))
	
	SELECT @level = NULLIF(@level,0)
	
	INSERT INTO @tmpSite(site)
	SELECT val 
	FROM dbo.strSplit(@site,',')
		
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 
	
	IF @TotalItems = 0
	BEGIN
		SELECT @TotalItems = COUNT(1)				
		FROM ProblemAccountLimitDownline p WITH(NOLOCK)
			INNER JOIN customer c WITH(NOLOCK) ON p.custid = c.custid
			INNER JOIN custinfo u WITH(NOLOCK) ON p.userid = u.custid
		WHERE c.username LIKE '%' + @username + '%'
			AND c.roleid = ISNULL(@level,c.roleid)
			AND c.roleid IN (2,3,4)
			AND c.site IN (SELECT site FROM @tmpSite)
	END
	
	;WITH T AS (
	SELECT c.custid, c.username, c.roleid, c.currency, c.site, u.username as AddedBy, p.CreatedDate,
		ROW_NUMBER() OVER(ORDER BY p.CreatedDate DESC) rn
	FROM ProblemAccountLimitDownline p WITH(NOLOCK)
		INNER JOIN customer c WITH(NOLOCK) ON p.custid = c.custid
		INNER JOIN custinfo u WITH(NOLOCK) ON p.userid = u.custid
	WHERE c.username LIKE '%' + @username + '%'
		AND c.roleid = ISNULL(@level,c.roleid)
		AND c.roleid IN (2,3,4)
		AND c.site IN (SELECT site FROM @tmpSite)
	)	
	SELECT custid, username, e.currency, roleid, site, AddedBy, CreatedDate
	FROM T
		INNER JOIN exchange e WITH(NOLOCK) on t.currency = e.exchangeid
	WHERE rn BETWEEN @RowStart AND @RowEnd
	
END	
GO