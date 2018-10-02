/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_MenuItem_Search]
	@MenuItemName	NVARCHAR(50),
	@SiteId			INT,
	@Environment	VARCHAR(10)		= 'UAT',	-- 'UAT', 'LIVE'
	@IsActive		BIT				= NULL
AS

/**  
 * Created	: 20120829@Edward
 * Task		: Search menu item
 * DB		: bodb_NAP
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	     
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
		dbo.NAP_MenuItems AS m WITH (NOLOCK)
		INNER JOIN dbo.NAP_Functions AS f WITH (NOLOCK) ON m.FunctionId = f.FunctionId
		INNER JOIN dbo.NAP_Sites AS s WITH (NOLOCK) ON m.SiteId = s.SiteId
		LEFT JOIN CustDB.dbo.custInfo AS cb WITH (NOLOCK) ON m.CreatedBy = cb.custid
		LEFT JOIN CustDB.dbo.custInfo AS mb WITH (NOLOCK) ON m.ModifiedBy = mb.custid
	WHERE 
		(@Environment = 'UAT' OR (@Environment != 'UAT' AND m.Environment = @Environment))
		AND (@IsActive IS NULL OR (@IsActive IS NOT NULL AND m.IsActive = @IsActive))
		AND (@SiteId = 0 OR (@SiteId != 0 AND m.SiteId = @SiteId))
		AND m.MenuItemName LIKE '%' + @MenuItemName + '%'
END
GO
GRANT EXECUTE ON [dbo].[NAP_MenuItem_Search] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_MenuItem_Search] TO [vnteam] AS [dbo]