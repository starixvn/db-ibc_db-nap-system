 ALTER PROCEDURE [dbo].[NAP_Site_GetById]
	@SiteId INT
AS
/*  
 * Created	: 20120809@Edward
 * Task		: Get information of site
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
    WHERE SiteId = @SiteId
END

GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetById] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetById] TO [vnteam] AS [dbo]