 ALTER PROCEDURE [dbo].[NAP_MenuItem_GetByNameAndSite]
	@MenuItemName	NVARCHAR(50),
	@SiteId			INT
AS

/**  
 * Created: 20120813@Kos
 * Task : Get menu item information in a site by menu item name
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
 */
BEGIN
	SET NOCOUNT ON

	SELECT 
		m.MenuItemId,
		m.FunctionId,
		f.FunctionName,
		m.SiteId,
		s.SiteName,
		m.MenuItemName,
		m.Description,
		m.ParentId,
		m.ParentName,
		m.Policy,
		m.URL,
		m.DisplayOrder,
		m.IsActive,
		m.CreatedBy		AS CreatorId,
		cb.username		AS CreatorUsername,
		m.CreatedDate,
		m.ModifiedBy	AS ModifierId,
		mb.username		AS ModifierUsername,
		m.ModifiedDate,
		m.Environment	
	FROM 
		dbo.MenuItems AS m WITH (NOLOCK)
		INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON m.FunctionId = f.FunctionId
		INNER JOIN dbo.Sites AS s WITH (NOLOCK) ON m.SiteId = s.SiteId
		LEFT JOIN bodb02.dbo.custInfo AS cb WITH (NOLOCK) ON m.CreatedBy = cb.custid
		LEFT JOIN bodb02.dbo.custInfo AS mb WITH (NOLOCK) ON m.ModifiedBy = mb.custid
	WHERE 
		m.MenuItemName = @MenuItemName
		AND m.SiteId = @SiteId
END


GO
GRANT EXECUTE ON [dbo].[NAP_MenuItem_GetByNameAndSite] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_MenuItem_GetByNameAndSite] TO [vnteam] AS [dbo]