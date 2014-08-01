USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_User_GetByGroupAndSite]    Script Date: 8/1/2014 1:49:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_User_GetByGroupAndSite]
    @GroupId    INT
    ,@SiteId    INT
    ,@IsActive  BIT		= NULL
AS

/*  
 * Created: 20120820@Edward
 * Task : Get user by group ID and site ID
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/

BEGIN
    SET NOCOUNT ON    
     
    SELECT DISTINCT 
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
		LEFT JOIN dbo.UserSite AS us WITH (NOLOCK) ON u.UserId = us.UserId
    WHERE 
		(@SiteId = 0 OR (@SiteId != 0 AND us.SiteId = @SiteId) )
		AND (@IsActive IS NULL OR (@IsActive IS NOT NULL AND us.IsActive = @IsActive))
		AND (@GroupId = 0 OR (@GroupId != 0 AND u.GroupId = @GroupId))
	
END

GO
GRANT EXECUTE ON [dbo].[NAP_User_GetByGroupAndSite] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_GetByGroupAndSite] TO [vnteam] AS [dbo]