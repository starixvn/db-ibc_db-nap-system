USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_LogUserLogin_Search]    Script Date: 8/1/2014 1:40:27 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
 * DB: bodb_NAP
 *  
 * Revisions:     
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
			bodb_NAPLog.dbo.NAPLog_UserLogin AS lu WITH (NOLOCK)
			INNER JOIN Users AS u WITH (NOLOCK) ON lu.UserId = u.UserId
			INNER JOIN bodb02.dbo.custInfo AS cu WITH (NOLOCK) ON u.UserId = cu.custid				
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
				bodb_NAPLog.dbo.NAPLog_UserLogin AS lu WITH (NOLOCK)
				INNER JOIN Users AS u WITH (NOLOCK) ON lu.UserId = u.UserId
				INNER JOIN bodb02.dbo.custInfo AS cu WITH (NOLOCK) ON u.UserId = cu.custid				
				LEFT JOIN Sites AS s WITH (NOLOCK) ON lu.SiteId = s.SiteId
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