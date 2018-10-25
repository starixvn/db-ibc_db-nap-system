/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Site_GetAllWithNumOfUser]
    @Environment	VARCHAR(10)	= 'UAT' -- 'UAT, 'LIVE'
    ,@IsActive		BIT			= NULL
AS
/*  
 * Created	: 20120829@Lewis
 * Task		: Get all sites with their number of users
 * DB		: bodb_NAP
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	
 * Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	SELECT 
		 s.SiteId
		,s.SiteName
		,s.Description
		,s.URL
		,s.TestURL
		,s.IsActive
		,s.Environment
		,COUNT(us.UserId) AS NumOfUser
	FROM 
		dbo.NAP_Sites s WITH (NOLOCK)
		LEFT JOIN dbo.NAP_UserSite us WITH (NOLOCK) ON s.SiteId = us.SiteId
	WHERE 
		(@Environment = 'UAT' OR (@Environment != 'UAT' AND s.Environment = @Environment))
		AND (@IsActive IS NULL OR (@IsActive IS NOT NULL AND s.IsActive = @IsActive))
	GROUP BY 
		s.SiteId
		,s.SiteName
		,s.Description
		,s.URL
		,s.TestURL
		,s.IsActive
		,s.Environment
END

GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetAllWithNumOfUser] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetAllWithNumOfUser] TO [vnteam] AS [dbo]