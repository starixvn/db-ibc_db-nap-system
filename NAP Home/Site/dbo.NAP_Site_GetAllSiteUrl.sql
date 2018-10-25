/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Site_GetAllSiteUrl]
    @Environment	VARCHAR(10)		-- UAT, LIVE
AS

/*  
 * Created	: 20121012@Lewis
 * Task		: Get all site URLs
 * DB		: DBPOL/NAP_UserControl
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]     
	
 * Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON

	SELECT 
		su.SiteURLId, 
		su.URL, 
		su.Environment, 
		su.IsActive, 
		su.IsDefault, 
		s.SiteId		AS Id, 
		s.SiteName		AS [Name], 
		s.Description, 
		s.IsActive		AS SiteIsActive, 
		s.Environment	AS SiteEnvironment
	FROM
		dbo.NAP_SiteURL su WITH (NOLOCK)
		INNER JOIN dbo.NAP_Sites s WITH (NOLOCK) ON su.SiteId = s.SiteId
	WHERE su.Environment = @Environment
END

GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetAllSiteUrl] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetAllSiteUrl] TO [vnteam] AS [dbo]