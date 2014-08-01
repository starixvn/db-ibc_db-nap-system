USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Group_GetGroupByFunctionAndSite]    Script Date: 8/1/2014 1:37:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--EXEC NAP_Group_GetAll

ALTER PROCEDURE [dbo].[NAP_Group_GetGroupByFunctionAndSite]
    @FunctionId	INT
	,@SiteId	INT
AS
/*  
 * Created	: 20120810@Edward
 * Task		: Get all group in a site and have permission in function
 * DB		: bodb_NAP
 *  
 * Revisions:
     
 * Param's Explanation: 
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
		dbo.Groups AS g WITH (NOLOCK)   
		LEFT JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON g.CreatedBy = ci.custid
		LEFT JOIN bodb02.dbo.custInfo AS ci1 WITH (NOLOCK) ON g.ModifiedBy = ci1.custid
		INNER JOIN GroupFunction AS gf WITH(NOLOCK) ON g.GroupId=gf.GroupId
		LEFT JOIN bodb02.dbo.custInfo AS ci3 WITH (NOLOCK) ON gf.CreatedBy = ci3.custid
		LEFT JOIN bodb02.dbo.custInfo AS ci4 WITH (NOLOCK) ON gf.ModifiedBy = ci4.custid
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