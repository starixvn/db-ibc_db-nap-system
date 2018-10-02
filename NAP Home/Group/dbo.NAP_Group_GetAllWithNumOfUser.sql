/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Group_GetAllWithNumOfUser]
	@GroupName		VARCHAR(50) = NULL,
	@Environment	VARCHAR(10) = 'UAT',
    @IsActive		BIT			= NULL 	
AS
/*  
	Created: 20120830@Kos
	Task : Get all group with number of user
	DB: DBPOL/NAP_UserControl

	Revisions:     
		- 10292012@Edward add input @GroupName
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]

	Param's Explanation: 
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
		(
			SELECT COUNT(Temp.UserId)
			FROM(
				SELECT DISTINCT u.UserId
				FROM dbo.NAP_Users AS u WITH (NOLOCK)
				LEFT JOIN dbo.NAP_UserSite AS us WITH (NOLOCK) ON u.UserId = us.UserId
				LEFT JOIN dbo.NAP_Sites AS s WITH (NOLOCK) ON us.SiteId = s.SiteId
				WHERE (@Environment = 'UAT' OR (@Environment != 'UAT' AND s.Environment = @Environment))
				AND u.GroupId = g.GroupId
				UNION
				SELECT DISTINCT u.UserId
				FROM dbo.NAP_Users AS u WITH (NOLOCK)
				WHERE u.UserId NOT IN (	SELECT DISTINCT UserId FROM dbo.NAP_UserSite WITH (NOLOCK))
				AND u.GroupId = g.GroupId
			) AS Temp
		)					AS NumOfUser,
		g.CreatedBy			AS CreatorId,
		ci.Username			AS CreatorUsername,
		g.ModifiedBy		AS ModifierId,
		ci1.Username		AS ModifierUsername		
	FROM 
		dbo.NAP_Groups AS g WITH (NOLOCK)   
		LEFT JOIN CustDB.dbo.custInfo AS ci WITH (NOLOCK) ON g.CreatedBy = ci.custid
		LEFT JOIN CustDB.dbo.custInfo AS ci1 WITH (NOLOCK) ON g.ModifiedBy = ci1.custid
	WHERE 
		(@IsActive IS NULL OR (@IsActive IS NOT NULL AND g.IsActive = @IsActive))
		AND (@GroupName IS NULL OR (@GroupName IS NOT NULL AND g.GroupName LIKE '%'+ @GroupName + '%'))

END
GO
GRANT EXECUTE ON [dbo].[NAP_Group_GetAllWithNumOfUser] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Group_GetAllWithNumOfUser] TO [vnteam] AS [dbo]