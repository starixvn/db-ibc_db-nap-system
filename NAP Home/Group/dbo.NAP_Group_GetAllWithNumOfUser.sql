USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Group_GetAllWithNumOfUser]    Script Date: 8/1/2014 1:36:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Group_GetAllWithNumOfUser]
	@GroupName		VARCHAR(50) = NULL,
	@Environment	VARCHAR(10) = 'UAT',
    @IsActive		BIT			= NULL 	
AS
/*  
 * Created: 20120830@Kos
 * Task : Get all group with number of user
 * DB: bodb_NAP
 *  
 * Revisions:     
	10292012@Edward add input @GroupName
 * Param's Explanation: 
*/
BEGIN
	SET NOCOUNT ON    
     
	SELECT 
		g.GroupId,
		g.GroupName,
		g.Description,
		g.IsActive,
		g.CreatedDate,
		g.ModifiedDate,
--		COUNT(u.UserId)		AS NumOfUser,
		(
			SELECT COUNT(Temp.UserId)
			FROM(
				SELECT DISTINCT u.UserId
				FROM Users AS u WITH (NOLOCK)
				LEFT JOIN UserSite AS us WITH (NOLOCK) ON u.UserId = us.UserId
				LEFT JOIN Sites AS s WITH (NOLOCK) ON us.SiteId = s.SiteId
				WHERE (@Environment = 'UAT' OR (@Environment != 'UAT' AND s.Environment = @Environment))
				AND u.GroupId = g.GroupId
				UNION
				SELECT DISTINCT u.UserId
				FROM Users AS u WITH (NOLOCK)
				WHERE u.UserId NOT IN (	SELECT DISTINCT UserId FROM UserSite WITH (NOLOCK))
				AND u.GroupId = g.GroupId
			) AS Temp
		)					AS NumOfUser,
		g.CreatedBy			AS CreatorId,
		ci.Username			AS CreatorUsername,
		g.ModifiedBy		AS ModifierId,
		ci1.Username		AS ModifierUsername		
	FROM 
		dbo.Groups AS g WITH (NOLOCK)   
		LEFT JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON g.CreatedBy = ci.custid
		LEFT JOIN bodb02.dbo.custInfo AS ci1 WITH (NOLOCK) ON g.ModifiedBy = ci1.custid
--		LEFT JOIN dbo.Users AS u WITH (NOLOCK) ON g.GroupId = u.GroupId		
	WHERE 
		(@IsActive IS NULL OR (@IsActive IS NOT NULL AND g.IsActive = @IsActive))
		AND (@GroupName IS NULL OR (@GroupName IS NOT NULL AND g.GroupName LIKE '%'+ @GroupName + '%'))
--	GROUP BY
--		g.GroupId,
--		g.GroupName,
--		g.Description,
--		g.IsActive,
--		g.CreatedDate,
--		g.ModifiedDate,
--		g.CreatedBy,
--		ci.Username,
--		g.ModifiedBy,
--		ci1.Username	
END

GO
GRANT EXECUTE ON [dbo].[NAP_Group_GetAllWithNumOfUser] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Group_GetAllWithNumOfUser] TO [vnteam] AS [dbo]