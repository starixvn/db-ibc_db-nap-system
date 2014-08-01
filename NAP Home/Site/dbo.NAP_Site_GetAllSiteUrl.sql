USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Site_GetAllSiteUrl]    Script Date: 8/1/2014 1:40:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Site_GetAllSiteUrl]
    @Environment	VARCHAR(10)		-- UAT, LIVE
AS

/*  
 * Created	: 20121012@Lewis
 * Task		: Get all site URLs
 * DB		: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON

	SELECT 
		su.SiteURLId, 
		su.URL, 
		su.Environment, 
		su.IsActive, 
		su.IsDefault, 
		s.SiteId		AS Id, 
		s.SiteName		AS [Name], 
		s.Description, 
		s.IsActive		AS SiteIsActive, 
		s.Environment	AS SiteEnvironment
	FROM
		dbo.SiteURL su WITH (NOLOCK)
		INNER JOIN dbo.Sites s WITH (NOLOCK) ON su.SiteId = s.SiteId
	WHERE su.Environment = @Environment
END

GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetAllSiteUrl] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetAllSiteUrl] TO [vnteam] AS [dbo]