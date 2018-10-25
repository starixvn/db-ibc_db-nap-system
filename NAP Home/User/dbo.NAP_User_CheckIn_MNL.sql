/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_User_CheckIn_MNL]
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
 * DB: DBPOL-NAP_UserControl
 *  
 * Revisions:
	- 20121026@Edward: add input param LoginDate
	- 20121026@Kos: Support MNL login
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	
 * Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON

	SET @OnUserId = IDENT_CURRENT('OnUser')
END
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_CheckIn_MNL] TO [vnteam]
GO 
GRANT EXECUTE ON [dbo].[NAP_User_CheckIn_MNL] TO [bodbAdminNet]
GO 
