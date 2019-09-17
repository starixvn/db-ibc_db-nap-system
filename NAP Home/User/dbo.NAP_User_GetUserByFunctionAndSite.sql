
/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_User_GetUserByFunctionAndSite] @FunctionId INT, 
                                                          @SiteId     INT = 0
AS

/*  
 * Created: 20120820@Edward
 * Task : Get all user
 * DB: DBPOL-NAP_UserControl
 *  
 * Revisions:
- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
- 20190913@Jacob: Support remove all permission on function - [Redmine:120213]	     
 * Param's Explanation: 
*/

     SET NOCOUNT ON;
     SELECT uf.Policy, 
            u.UserId, 
            c.firstname, 
            c.lastname, 
            c.email, 
            ci.username, 
            c.userpwd, 
            u.LastLoginDate, 
            u.CreatedDate, 
            u.ModifiedDate, 
            g.GroupId, 
            g.GroupName, 
            ci1.custid AS CreatorId, 
            ci1.username AS CreatorUsername, 
            ci2.custid AS ModifierId, 
            ci2.username AS ModifierUsername, 
            uf.CreatedBy AS CreatorIdUserFunction, 
            ci3.username AS CreatorUsernameUserFunction, 
            uf.ModifiedBy AS ModifierIdUserFunction, 
            ci4.username AS ModifierUsernameUserFunction, 
            uf.CreatedDate AS CreatedDateUserFunction, 
            uf.ModifiedDate AS ModifiedDateUserFunction
     FROM dbo.NAP_Users AS u WITH(NOLOCK)
          INNER JOIN CustDB.dbo.Customer AS C WITH(NOLOCK) ON u.UserId = c.custid
          INNER JOIN CustDB.dbo.custInfo AS ci WITH(NOLOCK) ON u.UserId = ci.custid
          LEFT JOIN dbo.NAP_Groups AS g WITH(NOLOCK) ON g.GroupId = u.GroupId
          LEFT JOIN CustDB.dbo.custInfo AS ci1 WITH(NOLOCK) ON u.CreatedBy = ci1.custid
          LEFT JOIN CustDB.dbo.custInfo AS ci2 WITH(NOLOCK) ON u.ModifiedBy = ci2.custid
          INNER JOIN dbo.NAP_UserFunction AS uf WITH(NOLOCK) ON u.UserId = uf.UserId
          LEFT JOIN CustDB.dbo.custInfo AS ci3 WITH(NOLOCK) ON uf.CreatedBy = ci3.custid
          LEFT JOIN CustDB.dbo.custInfo AS ci4 WITH(NOLOCK) ON uf.ModifiedBy = ci4.custid
     WHERE uf.FunctionId = @FunctionId
           AND uf.Policy > 0;
GO