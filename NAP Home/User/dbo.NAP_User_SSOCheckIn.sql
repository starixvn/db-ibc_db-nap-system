/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_User_SSOCheckIn]
	@UserId				INT
	,@SiteId			INT
	,@CheckOnUserId		INT
	,@NetSessionId		VARCHAR(30)
	,@OnUserId			INT					OUTPUT
	,@IP				VARCHAR(50)	= ''
	,@LoginDate			DATETIME	= NULL
AS

/*  
 * Created: 20120823@Edward
 * Task : User SSO check in
 * DB: DBPOL-NAP_UserControl
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	     
 * Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON
		
	-- check for onuser is kicked out
	IF EXISTS (	SELECT TOP(1) * 
				FROM dbo.NAP_OnUser
				WHERE Id = @CheckOnUserId AND IsKickedOut = 0 )
		BEGIN
			
			UPDATE dbo.NAP_OnUser WITH (ROWLOCK, UPDLOCK)
			SET IsKickedOut = 1 
			WHERE UserId = @UserId 	
			AND SiteId = @SiteId

			-- Insert new onuser
			INSERT INTO dbo.NAP_OnUser(UserId, SiteId, IsKickedOut, IP, NetSessionId)
			VALUES (@UserId, @SiteId, 0, @IP, @NetSessionID)
		
			SET @OnUserId = SCOPE_IDENTITY()	

			-- Update last login date
			IF (@SiteId = 0)	-- NAP Hub
				BEGIN
					UPDATE dbo.NAP_Users
					SET LastLoginDate = @LoginDate
					WHERE UserId = @UserId
				END
			ELSE
				BEGIN
					UPDATE dbo.NAP_UserSite
					SET LastLoginDate = @LoginDate
					WHERE SiteId = @SiteId AND UserId=@UserId
				END	
		END	
END


GO
GRANT EXECUTE ON [dbo].[NAP_User_SSOCheckIn] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_SSOCheckIn] TO [vnteam] AS [dbo]