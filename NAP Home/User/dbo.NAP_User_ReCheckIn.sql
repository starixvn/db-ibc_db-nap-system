/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_User_ReCheckIn]	
	@OnUserId			INT 
	,@IsKickedOut		BIT = 0 OUTPUT    
AS

/*  
 * Created: 20120823@Edward
 * Task : User recheckin
 * DB: bodb_NAP
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	     
 * Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON	

	IF EXISTS (	SELECT 1 
				FROM dbo.NAP_OnUser WITH (NOLOCK) 
				WHERE Id = @OnUserId AND IsKickedOut = 1 )    
		BEGIN    
			SET @IsKickedOut = 1    		
		END    
	ELSE    
		BEGIN    
			SET @IsKickedOut = 0    

			UPDATE dbo.NAP_OnUser WITH (ROWLOCK, UPDLOCK)
			SET ReloadTime = GETDATE()     
			WHERE Id = @OnUserId    
		     
			IF @@ROWCOUNT = 0    
				SELECT @IsKickedOut = 1    
		END
END

GO
GRANT EXECUTE ON [dbo].[NAP_User_ReCheckIn] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_ReCheckIn] TO [vnteam] AS [dbo]