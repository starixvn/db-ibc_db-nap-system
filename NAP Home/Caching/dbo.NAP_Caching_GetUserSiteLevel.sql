/*<info serverAlias="DBPOL-NAP_UserControl" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[NAP_Caching_GetUserSiteLevel]
AS

/*  
 * Created: 20240701@Jacob
 * Task : Cache data on web server
 * DB: DBPOL-NAP_UserControl
 *  
 * Revisions:
	- 20240701@Jacob: Implement Data Caching - [Redmine:207784]
	     
 * Param's Explanation: 
*/

    BEGIN
        SET NOCOUNT ON;
        SELECT us.UserId, 
               us.[Level], 
               us.IsActive, 
               us.SiteId, 
               s.SiteName, 
               s.Environment
        FROM dbo.NAP_UserSite us WITH(NOLOCK)
             INNER JOIN dbo.NAP_Sites s WITH(NOLOCK) ON us.SiteId = s.SiteId
        WHERE s.IsActive = 1;
    END;