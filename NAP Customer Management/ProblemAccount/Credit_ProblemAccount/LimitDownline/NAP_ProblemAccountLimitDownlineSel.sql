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
		- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
		- 20221114@Johnson: enhance sp [redmine: #180413]
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
	SELECT value 
	FROM STRING_SPLIT(@site,',')
	WHERE value <> ''
		
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 
	
	IF @TotalItems = 0
	BEGIN
		SELECT @TotalItems = COUNT(1)				
		FROM ProblemAccountLimitDownline p WITH(NOLOCK)
			CROSS APPLY (SELECT TOP (1) c.custid
							FROM customer c WITH(NOLOCK) 
							INNER JOIN custinfo u WITH(NOLOCK) ON p.userid = u.custid
						WHERE c.username LIKE '%' + @username + '%'
							AND c.roleid = ISNULL(@level,c.roleid)
							AND c.roleid IN (2,3,4)
							AND c.site IN (SELECT site FROM @tmpSite)
							AND p.custid = c.custid
						)tmp
	END
	
	;WITH T AS (
	SELECT tmp.custid, username, roleid, currency, site, AddedBy, p.CreatedDate,
		ROW_NUMBER() OVER(ORDER BY p.CreatedDate DESC) rn
	FROM ProblemAccountLimitDownline p WITH(NOLOCK)
		CROSS APPLY (SELECT TOP (1)  c.custid, c.username, c.roleid, c.currency, c.site, u.username as AddedBy
							FROM customer c WITH(NOLOCK) 
							INNER JOIN custinfo u WITH(NOLOCK) ON p.userid = u.custid
						WHERE c.username LIKE '%' + @username + '%'
							AND c.roleid = ISNULL(@level,c.roleid)
							AND c.roleid IN (2,3,4)
							AND c.site IN (SELECT site FROM @tmpSite)
							AND p.custid = c.custid
						)tmp
	)	
	SELECT custid, username, e.currency, roleid, site, AddedBy, CreatedDate
	FROM T
		INNER JOIN exchange e WITH(NOLOCK) on t.currency = e.exchangeid
	WHERE rn BETWEEN @RowStart AND @RowEnd
	
END	
GO