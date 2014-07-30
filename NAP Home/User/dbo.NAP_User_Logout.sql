USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_User_Logout]    Script Date: 02/27/2013 09:33:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[NAP_User_Logout]
	@OnUserID INT
AS

/*  
 * Created: 20120820@Edward
 * Task : User logout
 * DB: bodb_NAP
 *  
 * Revisions: 20130227@Edward  Update bug for logout NAP Hub  		
 * Param's Explanation: 		
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @userId	INT
	SET @userId = 0	

	SELECT @userId = ou.UserId
	FROM OnUser AS ou WITH (NOLOCK) 
	WHERE Id = @OnUserID AND SiteId = 0
	
	IF(@userId != 0)
	BEGIN
		UPDATE OnUser WITH (ROWLOCK, UPDLOCK)
		SET IsKickedOut = 1 
		WHERE UserId = @UserId 	
		AND SiteId != 0
	END

	DELETE FROM OnUser WHERE Id = @OnUserID

END




GO
GRANT EXECUTE ON [dbo].[NAP_User_Logout] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_Logout] TO [vnteam]