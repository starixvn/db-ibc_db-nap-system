 
ALTER PROCEDURE [dbo].[NAP_User_GetUserFunctionPolicy]
    @UserId				INT
    ,@FunctionId        INT
AS

/*  
 * Created: 20120820@Edward
 * Task : Get policy of user function
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/

BEGIN
    SET NOCOUNT ON    
     
    SELECT 
		CASE 
			WHEN ISNULL(A.Policy, 0) < ISNULL(B.Policy, 0) THEN ISNULL(B.Policy, 0) 
			ELSE ISNULL(A.Policy, 0) 
		END AS Policy
	FROM 
		(
			-- Get function permission of user in a site
			SELECT uf.FunctionId, uf.Policy
			FROM 
				UserFunction AS uf WITH (NOLOCK)
				INNER JOIN Functions AS f WITH(NOLOCK) ON uf.FunctionId = f.FunctionId
			WHERE 
				uf.UserId = @UserId 
				AND uf.FunctionId = @FunctionId
				AND f.IsActive = 1
		) AS A
		FULL OUTER JOIN
		(
			-- Get function permission of group of user in a site
			SELECT gf.FunctionId, gf.Policy
			FROM 
				GroupFunction AS gf WITH (NOLOCK)
				INNER JOIN Users AS u WITH (NOLOCK) ON u.GroupId = gf.GroupId
				INNER JOIN Functions AS f WITH(NOLOCK) ON gf.FunctionId = f.FunctionId
			WHERE 
				u.UserId = @UserId
				AND gf.FunctionId = @FunctionId
				AND f.IsActive = 1
		) AS B
		ON A.FunctionId = B.FunctionId
END

GO
GRANT EXECUTE ON [dbo].[NAP_User_GetUserFunctionPolicy] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_GetUserFunctionPolicy] TO [vnteam] AS [dbo]