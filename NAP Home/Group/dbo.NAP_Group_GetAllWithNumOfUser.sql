 -- EXEC NAP_Group_GetAllWithNumOfUser

ALTER PROCEDURE [dbo].[NAP_Group_GetAllWithNumOfUser]
	@GroupName	VARCHAR(50) = NULL,
    @IsActive	BIT			= NULL 	
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
		COUNT(u.UserId)		AS NumOfUser,
		g.CreatedBy			AS CreatorId,
		ci.Username			AS CreatorUsername,
		g.ModifiedBy		AS ModifierId,
		ci1.Username		AS ModifierUsername		
	FROM 
		dbo.Groups AS g WITH (NOLOCK)   
		LEFT JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON g.CreatedBy = ci.custid
		LEFT JOIN bodb02.dbo.custInfo AS ci1 WITH (NOLOCK) ON g.ModifiedBy = ci1.custid
		LEFT JOIN dbo.Users AS u WITH (NOLOCK) ON g.GroupId = u.GroupId		
	WHERE 
		(@IsActive IS NULL OR (@IsActive IS NOT NULL AND g.IsActive = @IsActive))
		AND (@GroupName IS NULL OR (@GroupName IS NOT NULL AND g.GroupName LIKE '%'+ @GroupName + '%'))
	GROUP BY
		g.GroupId,
		g.GroupName,
		g.Description,
		g.IsActive,
		g.CreatedDate,
		g.ModifiedDate,
		g.CreatedBy,
		ci.Username,
		g.ModifiedBy,
		ci1.Username	
END


GO
GRANT EXECUTE ON [dbo].[NAP_Group_GetAllWithNumOfUser] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Group_GetAllWithNumOfUser] TO [vnteam] AS [dbo]