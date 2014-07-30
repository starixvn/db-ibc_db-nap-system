 ALTER PROCEDURE [dbo].[NAP_Site_GetSiteURLById]
	@SiteURLId INT
AS
/*  
 * Created	: 20121008@Lewis
 * Task		: Gets SiteUrl by its id
 * DB		: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/
BEGIN

	SET NOCOUNT ON

	SELECT 
		su.SiteURLId
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
		SiteURLId = @SiteURLId

END


GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetSiteURLById] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetSiteURLById] TO [vnteam] AS [dbo]