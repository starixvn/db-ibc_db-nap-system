USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Site_GetAllWithNumOfUser]    Script Date: 8/1/2014 1:41:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
		dbo.Sites s WITH (NOLOCK)
		LEFT JOIN dbo.UserSite us WITH (NOLOCK) ON s.SiteId = us.SiteId
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