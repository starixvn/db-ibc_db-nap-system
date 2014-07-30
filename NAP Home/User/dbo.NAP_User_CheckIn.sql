USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_User_CheckIn]    Script Date: 02/27/2013 09:46:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


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
	20121026@Edward add input param LoginDate
 * Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON	

	UPDATE OnUser WITH (ROWLOCK, UPDLOCK)
	SET IsKickedOut = 1 
	WHERE UserId = @UserId 	
	AND SiteId = @SiteId

	INSERT INTO OnUser(UserId, SiteId, IsKickedOut, IP, NetSessionId)
	VALUES (@UserId, @SiteId, 0, @IP, @NetSessionID)
	
	SET  @OnUserId = SCOPE_IDENTITY()

	IF (@SiteId = 0)
		BEGIN
			UPDATE Users
			SET LastLoginDate = @LoginDate
			WHERE UserId = @UserId
		END
	ELSE
		BEGIN
			UPDATE UserSite
			SET LastLoginDate = @LoginDate
			WHERE SiteId = @SiteId	
			AND UserId = @UserId
		END
END



GO
GRANT EXECUTE ON [dbo].[NAP_User_CheckIn] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_CheckIn] TO [vnteam]