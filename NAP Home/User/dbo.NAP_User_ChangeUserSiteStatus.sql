/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_User_ChangeUserSiteStatus]
    @UserId         INT
    ,@SiteId        INT
    ,@IsActive      BIT
AS
/*  
 * Created: 20120820@Edward
 * Task : Change user site status
 * DB: DBPOL-NAP_UserControl
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	     
 * Param's Explanation: 
*/
BEGIN
    SET NOCOUNT ON    
     
    UPDATE dbo.NAP_UserSite
    SET IsActive = @IsActive
    WHERE UserId = @UserId
	AND SiteId = @SiteId
END

GO
GRANT EXECUTE ON [dbo].[NAP_User_ChangeUserSiteStatus] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_ChangeUserSiteStatus] TO [vnteam] AS [dbo]