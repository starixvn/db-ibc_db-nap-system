 ALTER PROCEDURE [dbo].[NAP_User_GetById]
    @UserId INT
AS
/*  
 * Created: 20120820@Edward
 * Task : Get user by user id
 * DB: bodb_NAP
 *  
 * Revisions:     
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
		dbo.Users AS u WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Customer AS C WITH (NOLOCK) ON u.UserId = c.custid
		INNER JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON u.UserId = ci.custid
		LEFT JOIN dbo.Groups AS g WITH (NOLOCK) ON g.GroupId = u.GroupId
		LEFT JOIN bodb02.dbo.custInfo AS ci1 WITH (NOLOCK) ON u.CreatedBy = ci1.custid
		LEFT JOIN bodb02.dbo.custInfo AS ci2 WITH (NOLOCK) ON u.ModifiedBy = ci2.custid
    WHERE u.UserId = @UserId
END


GO
GRANT EXECUTE ON [dbo].[NAP_User_GetById] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_GetById] TO [vnteam] AS [dbo]