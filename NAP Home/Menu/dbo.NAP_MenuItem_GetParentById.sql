
ALTER PROCEDURE [dbo].[NAP_MenuItem_GetParentById]
	@MenuItemId		INT,
	@Environment	VARCHAR(10)	= 'UAT'	-- 'UAT', 'LIVE'
AS

/**  
 * Created: 20120810@Edward
 * Task : Get all menu not child of menuitemid
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
 */

BEGIN

	SET NOCOUNT ON

	-- SiteId of this menu item
	DECLARE @SiteId INT
	
	-- Get SiteId
	SELECT @SiteId = SiteId
	FROM MenuItems
	WHERE MenuItemId = @MenuItemId

	-- Get all menu item is child of this menu item in site
	;WITH MenuItemChild AS(
		SELECT  MenuItemId 
		FROM    MenuItems WITH (NOLOCK)
		WHERE   MenuItemId = @MenuItemId

		UNION ALL

		SELECT  t.MenuItemId 
		FROM    
			MenuItems AS t WITH (NOLOCK) 
			INNER JOIN MenuItemChild AS r ON t.ParentId = r.MenuItemId
	)

	-- Get list menu item not in list menu item child 
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
		m.MenuItemId NOT IN ( 
			SELECT  MenuItemId 
			FROM MenuItemChild) 
		AND m.SiteId=@SiteId
		AND (@Environment = 'UAT' OR (@Environment != 'UAT' AND m.Environment = @Environment))
END



GO
GRANT EXECUTE ON [dbo].[NAP_MenuItem_GetParentById] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_MenuItem_GetParentById] TO [vnteam]