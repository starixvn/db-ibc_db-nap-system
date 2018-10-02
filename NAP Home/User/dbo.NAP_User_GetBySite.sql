/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_User_GetBySite]
    @SiteId INT
    ,@IsActive BIT	= NULL
AS
/*  
 * Created: 20120820@Edward
 * Task : Get user by site id
 * DB: bodb_NAP
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	     
 * Param's Explanation: 
*/
BEGIN
    SET NOCOUNT ON    
     
    SELECT u.UserId
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
		INNER JOIN CustDB.dbo.custInfo AS ci WITH (NOLOCK) ON u.UserId = ci.custid
		LEFT JOIN dbo.NAP_Groups AS g WITH (NOLOCK) ON g.GroupId = u.GroupId
		LEFT JOIN CustDB.dbo.custInfo AS ci1 WITH (NOLOCK) ON u.CreatedBy = ci1.custid
		LEFT JOIN CustDB.dbo.custInfo AS ci2 WITH (NOLOCK) ON u.ModifiedBy = ci2.custid
		INNER JOIN [dbo].[NAP_UserSite] AS us WITH (NOLOCK) ON u.[UserId] = [us].[UserId]
    WHERE 
		(@SiteId = 0 OR (@SiteId!=0 AND [us].[SiteId] = @SiteId) )
		AND (@IsActive IS NULL OR (@IsActive IS NOT NULL AND [us].[IsActive] = @IsActive))
	
END
GO
GRANT EXECUTE ON [dbo].[NAP_User_GetBySite] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_GetBySite] TO [vnteam] AS [dbo]