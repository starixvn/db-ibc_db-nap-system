  ALTER PROCEDURE [dbo].[NAP_Cust_GetByUsername]
    @Username NVARCHAR(50)
AS

/*  
 * Created: 20120820@Edward
 * Task : Get customer by username
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
 */

BEGIN
    SET NOCOUNT ON    
     
    SELECT 
        c.firstname,
		c.lastname,
		c.email,
		c.username,
		c.userpwd        
    FROM 
		bodb02.dbo.Customer AS C WITH (NOLOCK)
	WHERE c.username = @Username 
END



GO
GRANT EXECUTE ON [dbo].[NAP_Cust_GetByUsername] TO [bodbAdminNet] AS [dbo]