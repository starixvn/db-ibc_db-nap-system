/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Site_GetById]
	@SiteId INT
AS

/*
	Created: 20120809@Edward
	Task: Get information of site
	DB: DBNAP.bodb_NAP
	Revisions:
		- 20160322@Kos: Add SiteKey, SecretAccessKey [#Redmine: 50864]
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
		
	Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		SiteId,
		SiteName,
		SiteKey,
		SecretAccessKey,
		Description,
		URL,
		TestURL,
		IsActive,
		Environment
	FROM dbo.NAP_Sites WITH (NOLOCK)
	WHERE SiteId = @SiteId
END

GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetById] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetById] TO [vnteam] AS [dbo]