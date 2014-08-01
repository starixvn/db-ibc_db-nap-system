USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_User_GetUserByFunctionAndSite]    Script Date: 8/1/2014 1:50:26 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_User_GetUserByFunctionAndSite]
	@FunctionId INT
	,@SiteId INT
AS

/*  
 * Created: 20120820@Edward
 * Task : Get all user
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/

BEGIN
    SET NOCOUNT ON    
     
    SELECT 
		uf.Policy 
		,u.UserId
        ,c.firstname
        ,c.lastname
		,c.email
        ,ci.username
        ,c.userpwd
        ,u.LastLoginDate
        ,u.CreatedDate
        ,u.ModifiedDate
        ,g.GroupId
        ,g.GroupName
        ,ci1.custid			AS CreatorId
        ,ci1.username		AS CreatorUsername
        ,ci2.custid			AS ModifierId
        ,ci2.username		AS ModifierUsername
		,uf.CreatedBy		AS CreatorIdUserFunction
		,ci3.username		AS CreatorUsernameUserFunction
		,uf.ModifiedBy		AS ModifierIdUserFunction
		,ci4.username		AS ModifierUsernameUserFunction
		,uf.CreatedDate		AS CreatedDateUserFunction
		,uf.ModifiedDate	AS ModifiedDateUserFunction
    FROM 
		dbo.Users AS u WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Customer AS C WITH (NOLOCK) ON u.UserId = c.custid
		INNER JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON u.UserId = ci.custid
		LEFT JOIN dbo.Groups AS g WITH (NOLOCK) ON g.GroupId = u.GroupId
		LEFT JOIN bodb02.dbo.custInfo AS ci1 WITH (NOLOCK) ON u.CreatedBy = ci1.custid
		LEFT JOIN bodb02.dbo.custInfo AS ci2 WITH (NOLOCK) ON u.ModifiedBy = ci2.custid
		INNER JOIN UserFunction AS uf WITH(NOLOCK) ON u.UserId = uf.UserId
		LEFT JOIN bodb02.dbo.custInfo AS ci3 WITH (NOLOCK) ON uf.CreatedBy = ci3.custid
		LEFT JOIN bodb02.dbo.custInfo AS ci4 WITH (NOLOCK) ON uf.ModifiedBy = ci4.custid
	WHERE 
		uf.FunctionId = @FunctionId
		AND uf.Policy > 0
		AND uf.SiteId = @SiteId
END

GO
GRANT EXECUTE ON [dbo].[NAP_User_GetUserByFunctionAndSite] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_GetUserByFunctionAndSite] TO [vnteam] AS [dbo]