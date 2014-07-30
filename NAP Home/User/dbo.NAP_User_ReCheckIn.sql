 

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
 * Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON	

	IF EXISTS (	SELECT 1 
				FROM OnUser WITH (NOLOCK) 
				WHERE Id = @OnUserId AND IsKickedOut = 1 )    
		BEGIN    
			SET @IsKickedOut = 1    		
		END    
	ELSE    
		BEGIN    
			SET @IsKickedOut = 0    

			UPDATE OnUser WITH (ROWLOCK, UPDLOCK)
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