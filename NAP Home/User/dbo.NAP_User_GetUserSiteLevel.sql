USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_User_GetUserSiteLevel]    Script Date: 8/1/2014 1:51:08 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_User_GetUserSiteLevel]
    @UserId         INT
    ,@SiteId        INT
AS
/*  
 * Created: 20120820@Edward
 * Task : Get level of user in site
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/
BEGIN
    SET NOCOUNT ON    
     
    SELECT us.Level
    FROM dbo.UserSite AS us WITH (NOLOCK)
    WHERE 
		us.UserId		= @UserId
		AND us.SiteId	= @SiteId
		AND us.IsActive = 1
END



GO
GRANT EXECUTE ON [dbo].[NAP_User_GetUserSiteLevel] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_GetUserSiteLevel] TO [vnteam] AS [dbo]