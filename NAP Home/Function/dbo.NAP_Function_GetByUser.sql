 ALTER PROCEDURE [dbo].[NAP_Function_GetByUser]
	@UserId			INT,				
	@Environment	VARCHAR(10)	= 'UAT'	-- 'UAT', 'LIVE'
AS

/**  
 * Created	: 20120810@Kos
 * Task		: Get all function permission of a user
 * DB		: bodb_NAP
 *  
 * Revisions:     

 * Param's Explanation: 
 */
BEGIN
	SET NOCOUNT ON

	SELECT 
		uf.FunctionId,
		f.FunctionName,	
		f.FunctionKey,
		f.CRUD,
		f.DisplayOrder, 
		f.IsActive,
		f.Environment,
		uf.Policy,
		uf.CreatedDate,
		uf.ModifiedDate,
		f.Description,
		f.ParentId,
		f.ParentName,
		f.SiteId,
		s.SiteName,
		uf.CreatedBy	AS CreatorId,		--creator
		cb.username		AS CreatorUsername,	
		uf.ModifiedBy	AS ModifierId,	--modifier
		mb.username		AS ModifierUsername	
	FROM 
		dbo.UserFunction AS uf WITH (NOLOCK)
		INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON uf.FunctionId = f.FunctionId
		INNER JOIN dbo.Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		LEFT JOIN bodb02.dbo.custInfo AS cb WITH (NOLOCK) ON uf.CreatedBy = cb.custid
		LEFT JOIN bodb02.dbo.custInfo AS mb WITH (NOLOCK) ON uf.ModifiedBy = mb.custid
	WHERE 
		uf.UserId = @UserId
		AND f.IsActive = 1 AND s.IsActive = 1
		AND (@Environment = 'UAT' OR (@Environment != 'UAT' AND f.Environment = @Environment))
END


GO
GRANT EXECUTE ON [dbo].[NAP_Function_GetByUser] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_GetByUser] TO [vnteam] AS [dbo]