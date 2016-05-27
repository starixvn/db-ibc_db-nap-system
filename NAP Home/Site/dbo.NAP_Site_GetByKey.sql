USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Site_GetSiteURLById]    Script Date: 8/1/2014 1:42:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[NAP_Site_GetByKey]
	@SiteKey VARCHAR(50)
AS

/*
 * Created: 20160322@Kos
 * Task: Get site information by site key
 * DB: DBNAP.bodb_NAP
 * Revisions:

 * Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		SiteId,
		SiteName,
		Description,
		URL,
		TestURL,
		IsActive,
		Environment
	FROM dbo.Sites WITH (NOLOCK)
	WHERE SiteKey = @SiteKey
END


GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetByKey] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetByKey] TO [vnteam] AS [dbo]