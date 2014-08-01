USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_User_SSOCheckIn]    Script Date: 8/1/2014 1:53:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON
		
	-- check for onuser is kicked out
	IF EXISTS (	SELECT TOP(1) * 
				FROM OnUser
				WHERE Id = @CheckOnUserId AND IsKickedOut = 0 )
		BEGIN
			
			UPDATE OnUser WITH (ROWLOCK, UPDLOCK)
			SET IsKickedOut = 1 
			WHERE UserId = @UserId 	
			AND SiteId = @SiteId

			-- Insert new onuser
			INSERT INTO OnUser(UserId, SiteId, IsKickedOut, IP, NetSessionId)
			VALUES (@UserId, @SiteId, 0, @IP, @NetSessionID)
		
			SET @OnUserId = SCOPE_IDENTITY()	

			-- Update last login date
			IF (@SiteId = 0)	-- NAP Hub
				BEGIN
					UPDATE Users
					SET LastLoginDate = @LoginDate
					WHERE UserId = @UserId
				END
			ELSE
				BEGIN
					UPDATE UserSite
					SET LastLoginDate = @LoginDate
					WHERE SiteId = @SiteId AND UserId=@UserId
				END	
		END	
END


GO
GRANT EXECUTE ON [dbo].[NAP_User_SSOCheckIn] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_SSOCheckIn] TO [vnteam] AS [dbo]