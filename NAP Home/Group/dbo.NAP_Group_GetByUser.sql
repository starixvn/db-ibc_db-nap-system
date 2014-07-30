 --EXEC NAP_Group_GetByUser 7771656
ALTER PROCEDURE [dbo].[NAP_Group_GetByUser]
    @UserId INT
AS
/*  
 * Created	: 20120810@Edward
 * Task		: Get group by user id
 * DB		: bodb_NAP
 *  
 * Revisions:     

 * Param's Explanation: 
*/
BEGIN
    SET NOCOUNT ON    
     
    SELECT g.GroupId
        ,g.GroupName
        ,g.Description
        ,g.IsActive
        ,g.CreatedDate
		,g.ModifiedDate
		,g.CreatedBy	AS CreatorId         
        ,ci.Username	AS CreatorUsername       
        ,g.ModifiedBy	AS ModifierId
        ,ci1.Username	AS ModifierUsername    
    FROM 
		dbo.Users AS u WITH (NOLOCK)
		INNER JOIN dbo.Groups AS g WITH (NOLOCK) ON g.GroupId = u.GroupId    
		LEFT JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON g.CreatedBy = ci.custid
		LEFT JOIN bodb02.dbo.custInfo AS ci1 WITH (NOLOCK) ON g.ModifiedBy = ci1.custid
    WHERE u.UserId = @UserId
END


GO
GRANT EXECUTE ON [dbo].[NAP_Group_GetByUser] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Group_GetByUser] TO [vnteam] AS [dbo]