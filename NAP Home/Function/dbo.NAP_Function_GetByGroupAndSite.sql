USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Function_GetByGroupAndSite]    Script Date: 8/1/2014 12:56:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Function_GetByGroupAndSite]
	@GroupId		INT,				
	@SiteId			INT,
	@Environment	VARCHAR(10)	= 'UAT'	-- 'UAT', 'LIVE'
AS

/**  
 * Created	: 20120810@Kos
 * Task		: Get all function permission of a group in a site
 * DB		: bodb_NAP
 *  
 * Revisions:   
  
 * Param's Explanation: 
 */
BEGIN
	SET NOCOUNT ON

	SELECT 
		gf.FunctionId,
		f.FunctionName,	
		f.FunctionKey,	
		gf.Policy,	
		gf.CreatedDate,	
		gf.ModifiedDate,
		f.Description,	
		f.CRUD,
		f.DisplayOrder,
		f.IsActive,
		f.Environment,
		f.ParentId,							-- parent information
		f.ParentName,		
		f.SiteId,							-- site information
		s.SiteName,
		gf.CreatedBy	AS CreatorId,			-- creator information
		cb.username		AS CreatorUsername,
		gf.ModifiedBy	AS ModifierId,		-- modifier information
		mb.username		AS ModifierUsername
	FROM 
		dbo.GroupFunction AS gf WITH (NOLOCK)
		INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId
		INNER JOIN dbo.Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		LEFT JOIN bodb02.dbo.custInfo AS cb WITH (NOLOCK) ON gf.CreatedBy = cb.custid
		LEFT JOIN bodb02.dbo.custInfo AS mb WITH (NOLOCK) ON gf.ModifiedBy = mb.custid
	WHERE 
		gf.GroupId = @GroupId
		AND s.SiteId = @SiteId
		AND f.IsActive = 1 AND s.IsActive = 1 -- check with site is active
		AND (@Environment = 'UAT' OR (@Environment != 'UAT' AND f.Environment = @Environment))
END

GO
GRANT EXECUTE ON [dbo].[NAP_Function_GetByGroupAndSite] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_GetByGroupAndSite] TO [vnteam] AS [dbo]