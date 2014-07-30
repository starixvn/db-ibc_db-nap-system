 
ALTER PROCEDURE [dbo].[NAP_User_GetUserSiteLevel]
    @UserId         INT
    ,@SiteId        INT
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
     
    SELECT us.Level
    FROM dbo.UserSite AS us WITH (NOLOCK)
    WHERE 
		us.UserId		= @UserId
		AND us.SiteId	= @SiteId
		AND us.IsActive = 1
END



GO
GRANT EXECUTE ON [dbo].[NAP_User_GetUserSiteLevel] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_GetUserSiteLevel] TO [vnteam] AS [dbo]