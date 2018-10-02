/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_User_GetAll]
AS

/*  
 * Created: 20120820@Edward
 * Task : Get all user
 * DB: DBPOL-NAP_UserControl
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	     
 * Param's Explanation: 
*/

BEGIN
    SET NOCOUNT ON    
     
    SELECT 
		u.UserId
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
        ,ci1.custid		AS CreatorId
        ,ci1.username	AS CreatorUsername
        ,ci2.custid		AS ModifierId
        ,ci2.username	AS ModifierUsername
    FROM 
		dbo.NAP_Users AS u WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer AS C WITH (NOLOCK) ON u.UserId = c.custid
		INNER JOIN CustDB.dbo.custInfo AS ci WITH (NOLOCK) ON u.UserId= ci.custid
		LEFT JOIN dbo.NAP_Groups AS g WITH (NOLOCK) ON g.GroupId = u.GroupId
		LEFT JOIN CustDB.dbo.custInfo AS ci1 WITH (NOLOCK) ON u.CreatedBy = ci1.custid
		LEFT JOIN CustDB.dbo.custInfo AS ci2 WITH (NOLOCK) ON u.ModifiedBy = ci2.custid
  
END

GO
GRANT EXECUTE ON [dbo].[NAP_User_GetAll] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_GetAll] TO [vnteam] AS [dbo]