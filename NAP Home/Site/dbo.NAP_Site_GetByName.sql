 ALTER PROCEDURE [dbo].[NAP_Site_GetByName]
	@SiteName VARCHAR(50)
AS
/*  
 * Created	: 20120810@Edward
 * Task		: Get information of site by name
 * DB		: bodb_NAP
 *  
 * Revisions:     
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
    FROM dbo.Sites WITH (NOLOCK)
    WHERE SiteName = @SiteName
END

GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetByName] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetByName] TO [vnteam] AS [dbo]