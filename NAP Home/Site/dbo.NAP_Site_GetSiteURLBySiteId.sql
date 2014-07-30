 ALTER PROCEDURE [dbo].[NAP_Site_GetSiteURLBySiteId]
    @SiteId			INT
    ,@Environment	VARCHAR(10)
AS
/*  
 * Created	: 20121010@Lewis
 * Task		: Get siteUrl by site id
 * DB		: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/
BEGIN
	SET NOCOUNT ON
	SELECT su.SiteURLId
		 , su.URL
		 , su.Environment
		 , su.IsActive
		 , su.IsDefault
		 , s.SiteId			AS Id
		 , s.SiteName		AS [Name]
		 , s.Description
		 , s.IsActive		AS SiteIsActive
		 , s.Environment	AS SiteEnvironment
	FROM
		dbo.SiteURL su WITH (NOLOCK)
		INNER JOIN dbo.Sites s WITH (NOLOCK) ON su.SiteId = s.SiteId
	WHERE
		su.SiteId = @SiteId
		AND su.Environment = @Environment
		
END


GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetSiteURLBySiteId] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetSiteURLBySiteId] TO [vnteam] AS [dbo]