 ALTER PROCEDURE [dbo].[NAP_Function_GetBySite]
	@SiteId			INT,
	@Environment	VARCHAR(10)	= 'UAT',	-- 'UAT', 'LIVE'
	@IsActive		BIT			= NULL
AS

/**  
 * Created	: 20120810@Kos
 * Task		: Get all function in a site filter with environment and isactive field
 * DB		: bodb_NAP
 *  
 * Revisions:     

 * Param's Explanation: 
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
		f.SiteId = @SiteId
		AND (@Environment = 'UAT' OR (@Environment != 'UAT' AND f.Environment = @Environment))
		AND (@IsActive IS NULL OR (@IsActive IS NOT NULL AND f.IsActive = @IsActive))
END


GO
GRANT EXECUTE ON [dbo].[NAP_Function_GetBySite] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_GetBySite] TO [vnteam] AS [dbo]