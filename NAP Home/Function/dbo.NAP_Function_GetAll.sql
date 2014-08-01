USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Function_GetAll]    Script Date: 8/1/2014 12:55:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Function_GetAll]
	@Environment	VARCHAR(10)	= 'UAT',	-- 'UAT', 'LIVE'
	@IsActive		BIT			= NULL
AS

/**  
 * Created: 20120810@Kos
 * Task : Get all function filter by @Environment and @IsActive
 * DB	: bodb_NAP
 *  
 * Revisions			:   
  
 * Param's Explanation	: 
	• @Environment	:	UAT or LIVE

	• @IsActive		:	NULL, true or false
 */
BEGIN

	SET NOCOUNT ON

	SELECT 
		f.FunctionId,	
		f.FunctionName,
		f.FunctionKey,
		f.Description,	
		f.CRUD,
		f.DisplayOrder,
		f.IsActive,
		f.CreatedDate,
		f.ModifiedDate,
		f.Environment,
		f.ParentId,							-- parent information
		f.ParentName,
		f.SiteId,							-- site information
		s.SiteName,
		f.CreatedBy		AS CreatorId,			-- creator information
		cb.username		AS CreatorUsername,	
		f.ModifiedBy	AS ModifierId,			-- modifier information
		mb.username		AS ModifierUsername	
	FROM 
		dbo.Functions AS f WITH (NOLOCK)
		INNER JOIN dbo.Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		LEFT JOIN bodb02.dbo.custInfo AS cb WITH (NOLOCK) ON f.CreatedBy = cb.custid
		LEFT JOIN bodb02.dbo.custInfo AS mb WITH (NOLOCK) ON f.ModifiedBy = mb.custid
	WHERE 
		(@Environment = 'UAT' OR (@Environment != 'UAT' AND f.Environment = @Environment))
		AND (@IsActive IS NULL OR (@IsActive IS NOT NULL AND f.IsActive = @IsActive))
END


GO
GRANT EXECUTE ON [dbo].[NAP_Function_GetAll] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_GetAll] TO [vnteam] AS [dbo]