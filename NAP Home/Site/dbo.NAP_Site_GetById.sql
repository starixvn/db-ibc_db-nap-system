USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Site_GetById]    Script Date: 8/1/2014 1:41:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Site_GetById]
	@SiteId INT
AS

/*
	Created: 20120809@Edward
	Task: Get information of site
	DB: DBNAP.bodb_NAP
	Revisions:
		- 20160322@Kos: Add SiteKey, SecretAccessKey [#Redmine: 50864]

	Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		SiteId,
		SiteName,
		SiteKey,
		SecretAccessKey,
		Description,
		URL,
		TestURL,
		IsActive,
		Environment
	FROM dbo.Sites WITH (NOLOCK)
	WHERE SiteId = @SiteId
END

GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetById] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetById] TO [vnteam] AS [dbo]