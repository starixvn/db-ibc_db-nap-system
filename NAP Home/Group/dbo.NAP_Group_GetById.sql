 ALTER PROCEDURE [dbo].[NAP_Group_GetById]
    @GroupId INT
AS
/*  
 * Created: 20120810@Edward
 * Task : Get group by group id
 * DB: bodb_NAP
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
		dbo.Groups AS g WITH (NOLOCK)  
		LEFT JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON g.CreatedBy = ci.custid
		LEFT JOIN bodb02.dbo.custInfo AS ci1 WITH (NOLOCK) ON g.ModifiedBy = ci1.custid
    WHERE g.GroupId = @GroupId
END


GO
GRANT EXECUTE ON [dbo].[NAP_Group_GetById] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Group_GetById] TO [vnteam] AS [dbo]