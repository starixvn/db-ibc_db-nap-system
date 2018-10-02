/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Group_GetGroupByFunctionAndSite]
    @FunctionId	INT
	,@SiteId	INT
AS
/*  
	Created	: 20120810@Edward
	Task	: Get all group in a site and have permission in function
	DB		: DBPOL/NAP_UserControl

	Revisions:
	 - 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	 
	Param's Explanation: 
*/
BEGIN
   SET NOCOUNT ON    
     
   SELECT 
		gf.Policy
		,g.GroupId
        ,g.GroupName
        ,g.Description
        ,g.IsActive
        ,g.CreatedDate
		,g.ModifiedDate
		,g.CreatedBy		AS CreatorId         
        ,ci.Username		AS CreatorUsername       
        ,g.ModifiedBy		AS ModifierId
        ,ci1.Username		AS ModifierUsername   
		,gf.CreatedBy		AS CreatorIdGroupFunction
		,ci3.username		AS CreatorUsernameGroupFunction
		,gf.ModifiedBy		AS ModifierIdGroupFunction
		,ci4.username		AS ModifierUsernameGroupFunction
		,gf.CreatedDate		AS CreatedDateGroupFunction
		,gf.ModifiedDate	AS ModifiedDateGroupFunction 
    FROM 
		dbo.NAP_Groups AS g WITH (NOLOCK)   
		LEFT JOIN CustDB.dbo.custInfo AS ci WITH (NOLOCK) ON g.CreatedBy = ci.custid
		LEFT JOIN CustDB.dbo.custInfo AS ci1 WITH (NOLOCK) ON g.ModifiedBy = ci1.custid
		INNER JOIN dbo.NAP_GroupFunction AS gf WITH(NOLOCK) ON g.GroupId=gf.GroupId
		LEFT JOIN CustDB.dbo.custInfo AS ci3 WITH (NOLOCK) ON gf.CreatedBy = ci3.custid
		LEFT JOIN CustDB.dbo.custInfo AS ci4 WITH (NOLOCK) ON gf.ModifiedBy = ci4.custid
	WHERE 
		gf.FunctionId	= @FunctionId
		AND g.IsActive	= 1				-- check for group is active
		AND gf.Policy	> 0				-- check for have permission that means policy > 0
		AND gf.SiteId	= @SiteId
END
GO
GRANT EXECUTE ON [dbo].[NAP_Group_GetGroupByFunctionAndSite] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Group_GetGroupByFunctionAndSite] TO [vnteam] AS [dbo]