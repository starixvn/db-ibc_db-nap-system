/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
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
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	     
 * Param's Explanation: 
*/

BEGIN
    SET NOCOUNT ON    
     
    SELECT 
		us.Level,
		us.IsActive
    FROM dbo.NAP_UserSite AS us WITH (NOLOCK)
    WHERE 
		us.UserId = @UserId
		AND us.SiteId = @SiteId		
END
GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetUserSiteLevel] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetUserSiteLevel] TO [vnteam] AS [dbo]