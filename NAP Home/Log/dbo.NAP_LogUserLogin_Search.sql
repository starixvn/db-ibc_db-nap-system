/*<info serverAlias="DBNAP-bodb_NAPLOG" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_LogUserLogin_Search]
    @Name			NVARCHAR(50)	= ''
	,@SiteId		INT				= 0
    ,@From			DATETIME
	,@To			DATETIME
	,@PageIndex		INT
	,@PageSize		INT
	,@TotalRows		INT				= 0		OUTPUT	
AS
/*  
 * Created: 20120820@Edward
 * Task : Search user login log
 * DB: DBNAP-bodb_NAPLOG
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration, Move to bodb_NAPLOG - [Redmine:100493]
	     
 * Param's Explanation: 
*/
BEGIN
	DECLARE @FirstRec INT, @LastRec INT
	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1
	SELECT @LastRec = ((@PageIndex * @PageSize + 1)) - 1

	SET NOCOUNT ON
		-- gets total rows
	SET @TotalRows = (
		SELECT COUNT(1)
		FROM 
			dbo.NAPLog_UserLogin AS lu WITH (NOLOCK)
			INNER JOIN bodb02.dbo.custInfo AS cu WITH (NOLOCK) ON lu.UserId = cu.custid				
		WHERE 
			cu.username LIKE '%' + @Name + '%'		
			AND lu.LogDate BETWEEN @From AND @To
			--AND (@SiteId = 0 OR (@SiteId != 0 AND lu.SiteId = @SiteId))
		AND lu.SiteId = @SiteId
	)

	-- gets data
	SELECT TOP (@PageSize) *
	FROM (
			SELECT 
				lu.Id,					
				lu.IP,
				lu.LogDate,
				lu.Doing,
				lu.DomainName,
				lu.BrowserName,
				lu.Platform,
				lu.CountryCode,
				lu.Duration,
				lu.UserId,
				cu.username,
				lu.SiteId,
				s.SiteName,
				row_number() OVER (ORDER BY lu.LogDate DESC) AS num
			FROM 
				dbo.NAPLog_UserLogin AS lu WITH (NOLOCK)
				INNER JOIN bodb02.dbo.custInfo AS cu WITH (NOLOCK) ON lu.UserId = cu.custid				
				LEFT JOIN DBPOL.NAP_UserControl.dbo.NAP_Sites AS s WITH (NOLOCK) ON lu.SiteId = s.SiteId
			WHERE 
				cu.username LIKE '%' + @Name + '%'		
				AND lu.LogDate BETWEEN @From AND @To
				--AND (@SiteId = 0 OR (@SiteId != 0 AND lu.SiteId = @SiteId))
				AND lu.SiteId = @SiteId
		) AS Temp
	WHERE
		Temp.num >= @FirstRec
		AND Temp.num <= @LastRec
	ORDER BY
		Temp.num	
END
GO
GRANT EXECUTE ON [dbo].[NAP_LogUserLogin_Search] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_LogUserLogin_Search] TO [vnteam]