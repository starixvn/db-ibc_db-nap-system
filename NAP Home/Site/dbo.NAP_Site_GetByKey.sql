/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Site_GetByKey]
	@SiteKey VARCHAR(50)
AS

/*
 * Created: 20160322@Kos
 * Task: Get site information by site key
 * DB: DBPOL-NAP_UserControl
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	
 * Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		SiteId,
		SiteName,
		Description,
		URL,
		TestURL,
		IsActive,
		Environment
	FROM dbo.NAP_Sites WITH (NOLOCK)
	WHERE SiteKey = @SiteKey
END
GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetByKey] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetByKey] TO [vnteam] AS [dbo]