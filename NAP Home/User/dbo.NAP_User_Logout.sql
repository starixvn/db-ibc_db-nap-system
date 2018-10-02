/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_User_Logout]
	@OnUserID INT
AS

/*  
 * Created: 20120820@Edward
 * Task : User logout
 * DB: DBPOL-NAP_UserControl
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	     
 * Param's Explanation: 		
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @userId	INT
	SET @userId = 0	

	SELECT @userId = ou.UserId
	FROM dbo.NAP_OnUser AS ou WITH (NOLOCK) 
	WHERE Id = @OnUserID AND SiteId = 0
	
	IF(@userId != 0)
	BEGIN
		UPDATE dbo.NAP_OnUser WITH (ROWLOCK, UPDLOCK)
		SET IsKickedOut = 1 
		WHERE UserId = @UserId 	
		AND SiteId != 0
	END

	DELETE FROM dbo.NAP_OnUser WHERE Id = @OnUserID

END
GO
GRANT EXECUTE ON [dbo].[NAP_User_Logout] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_Logout] TO [vnteam]