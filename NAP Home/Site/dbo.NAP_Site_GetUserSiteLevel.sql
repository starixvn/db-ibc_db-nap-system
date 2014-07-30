 ALTER PROCEDURE [dbo].[NAP_Site_GetUserSiteLevel]
    @UserId		INT,
	@SiteId		INT
AS

/*  
 * Created: 20120820@Edward
 * Task : Get level of user in site
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/

BEGIN
    SET NOCOUNT ON    
     
    SELECT 
		us.Level,
		us.IsActive
    FROM dbo.UserSite AS us WITH (NOLOCK)
    WHERE 
		us.UserId = @UserId
		AND us.SiteId = @SiteId		
END

GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetUserSiteLevel] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetUserSiteLevel] TO [vnteam] AS [dbo]