/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Site_GetByName]
	@SiteName VARCHAR(50)
AS
/*  
 * Created	: 20120810@Edward
 * Task		: Get information of site by name
 * DB		: bodb_NAP
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]     
	
 * Param's Explanation: 
*/
BEGIN
	SET NOCOUNT ON

    SELECT SiteId
		,SiteName
        ,Description
        ,URL
		,TestURL
        ,IsActive
        ,Environment
    FROM dbo.NAP_Sites WITH (NOLOCK)
    WHERE SiteName = @SiteName
END

GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetByName] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetByName] TO [vnteam] AS [dbo]