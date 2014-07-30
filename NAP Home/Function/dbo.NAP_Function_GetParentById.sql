 ALTER PROCEDURE [dbo].[NAP_Function_GetParentById]
	@FunctionId INT
AS

/**  
 * Created	: 20120810@Kos
 * Task		: Get all functions can be parent of FunctionId
 * DB		: bodb_NAP
 *  
 * Revisions	:     
 * Param's Explanation: 	
 */
BEGIN
	SET NOCOUNT ON
	
	-- Get SiteId of FunctionId
	DECLARE @SiteId INT
	SELECT @SiteId = SiteId
	FROM Functions
	WHERE FunctionId = @FunctionId

	-- Get all function is parent of FucntionId
	;WITH FunctionChild AS (
		SELECT FunctionId 
		FROM Functions WITH (NOLOCK)
		WHERE FunctionId = @FunctionId

		UNION ALL

		SELECT f.FunctionId 
		FROM    
			Functions AS f WITH(NOLOCK) 
			INNER JOIN FunctionChild fc ON f.ParentId = fc.FunctionId
	)
	
	-- Select information of list function can be parent of functionId
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
		f.FunctionId NOT IN ( 
			SELECT FunctionId 
			FROM FunctionChild
		) 
		AND f.SiteId = @SiteId
END


GO
GRANT EXECUTE ON [dbo].[NAP_Function_GetParentById] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_GetParentById] TO [vnteam] AS [dbo]