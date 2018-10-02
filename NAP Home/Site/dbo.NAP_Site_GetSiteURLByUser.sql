/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Site_GetSiteURLByUser]
    @UserId			INT
    ,@Environment	VARCHAR(10)
AS
/*  
 * Created	: 20121005@Lewis
 * Task		: Get siteUrl by user id
 * DB		: bodb_NAP
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	     
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
		dbo.NAP_Sites s WITH (NOLOCK)
		INNER JOIN dbo.NAP_UserSite us WITH (NOLOCK) ON us.SiteId = s.SiteId
		LEFT JOIN dbo.NAP_SiteURL su WITH (NOLOCK) ON su.SiteId = s.SiteId
	WHERE
		us.UserId = @UserId
		AND su.Environment	= @Environment
		AND su.IsActive		= 1
		AND us.IsActive		= 1
		AND s.IsActive		= 1
		
END
GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetSiteURLByUser] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetSiteURLByUser] TO [vnteam] AS [dbo]