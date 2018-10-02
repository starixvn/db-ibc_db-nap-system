/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Group_GetAll]
    @IsActive	BIT	= NULL 
AS

/*  
 * Created: 20120810@Edward
 * Task : Get all group
 * DB: DBPOL/NAP_UserControl
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]     
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
    FROM dbo.NAP_Groups AS g WITH (NOLOCK)   
    LEFT JOIN CustDB.dbo.custInfo AS ci WITH (NOLOCK) ON g.CreatedBy = ci.custid
	LEFT JOIN CustDB.dbo.custInfo AS ci1 WITH (NOLOCK) ON g.ModifiedBy = ci1.custid
    WHERE (@IsActive IS NULL OR (@IsActive IS NOT NULL AND g.IsActive = @IsActive))
	
END
GO
GRANT EXECUTE ON [dbo].[NAP_Group_GetAll] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Group_GetAll] TO [vnteam] AS [dbo]