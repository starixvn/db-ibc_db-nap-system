/*<info serverAlias="DBPOL-NAP_UserControl" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_Caching_GetUserFunctionsBySite] @SiteId INT = NULL
AS

/*  
 * Created: 20240701@Jacob
 * Task : Cache data on web server
 * DB: DBPOL-NAP_UserControl
 *  
 * Revisions:
	- 20240701@Jacob: Implement Data Caching - [Redmine:207784]
	     
 * Param's Explanation: 
*/

    BEGIN
        SET NOCOUNT ON;
        SELECT @SiteId = ISNULL(@SiteId, 0);
        SELECT f.SiteId, 
               P.UserId, 
			   P.[Policy],
               f.FunctionID               
        FROM
        (
            SELECT ISNULL(A.UserId, B.UserId) UserId, 
                   ISNULL(A.FunctionId, B.FunctionId) FunctionId,
                   CASE
                       WHEN ISNULL(A.[Policy], 0) < ISNULL(B.[Policy], 0)
                       THEN ISNULL(B.[Policy], 0)
                       ELSE ISNULL(A.[Policy], 0)
                   END AS [Policy]
            FROM
            (  
                -- Get function permission of @UserId in @SiteId  
                SELECT uf.FunctionId, 
                       uf.[Policy], 
                       uf.UserId
                FROM dbo.NAP_UserFunction AS uf WITH(NOLOCK)
            ) AS A
            FULL OUTER JOIN
            (  
                -- Get function permission of group where user belong to  
                SELECT gf.FunctionId, 
                       gf.[Policy], 
                       u.UserId
                FROM dbo.NAP_GroupFunction AS gf WITH(NOLOCK)
                     INNER JOIN dbo.NAP_Users AS u WITH(NOLOCK) ON u.GroupId = gf.GroupId
            ) AS B ON A.FunctionID = B.FunctionID
                      AND A.UserId = B.UserId
        ) P
        INNER JOIN dbo.NAP_Functions f WITH(NOLOCK) ON P.FunctionId = f.FunctionId        
        WHERE f.IsActive = 1              
              AND (@SiteId = 0
                   OR f.SiteId = @SiteId)
              AND P.[Policy] > 0
        ORDER BY SiteId, 
                 UserId, 
                 FunctionId, 
                 [Policy];
    END;