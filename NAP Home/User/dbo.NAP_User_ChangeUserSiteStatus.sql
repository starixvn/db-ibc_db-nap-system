 ALTER PROCEDURE [dbo].[NAP_User_ChangeUserSiteStatus]
    @UserId         INT
    ,@SiteId        INT
    ,@IsActive      BIT
AS
/*  
 * Created: 20120820@Edward
 * Task : Change user site status
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/
BEGIN
    SET NOCOUNT ON    
     
    UPDATE dbo.UserSite
    SET IsActive = @IsActive
    WHERE UserId = @UserId
	AND SiteId = @SiteId
END

GO
GRANT EXECUTE ON [dbo].[NAP_User_ChangeUserSiteStatus] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_ChangeUserSiteStatus] TO [vnteam] AS [dbo]