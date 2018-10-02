/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_User_CheckIn]
	@UserId				INT
	,@SiteId			INT
	,@NetSessionId		VARCHAR(30)
	,@OnUserId			INT OUTPUT
	,@IP				VARCHAR(50) = ''
	,@LoginDate			DATETIME  = NULL
AS

/*  
 * Created: 20120823@Edward
 * Task : User check in
 * DB: bodb_NAP
 *  
 * Revisions:  
	- 20121026@Edward add input param LoginDate
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	
 * Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON	

	UPDATE dbo.NAP_OnUser WITH (ROWLOCK, UPDLOCK)
	SET IsKickedOut = 1 
	WHERE UserId = @UserId 	
	AND SiteId = @SiteId

	INSERT INTO dbo.NAP_OnUser(UserId, SiteId, IsKickedOut, IP, NetSessionId)
	VALUES (@UserId, @SiteId, 0, @IP, @NetSessionID)
	
	SET  @OnUserId = SCOPE_IDENTITY()

	IF (@SiteId = 0)
		BEGIN
			UPDATE dbo.NAP_Users
			SET LastLoginDate = @LoginDate
			WHERE UserId = @UserId
		END
	ELSE
		BEGIN
			UPDATE dbo.NAP_UserSite
			SET LastLoginDate = @LoginDate
			WHERE SiteId = @SiteId	
			AND UserId = @UserId
		END
END
GO
GRANT EXECUTE ON [dbo].[NAP_User_CheckIn] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_CheckIn] TO [vnteam]