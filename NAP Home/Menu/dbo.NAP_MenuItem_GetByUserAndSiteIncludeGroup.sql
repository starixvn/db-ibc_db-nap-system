/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_MenuItem_GetByUserAndSiteIncludeGroup]
	@UserId			INT,				
	@SiteId			INT,				
	@Environment	VARCHAR(10)	= 'UAT'	-- 'UAT', 'LIVE'
AS

/**  
 * Created	: 20120810@Kos
 * Task		: Get all menu items of a user in a site include its group permission
 * DB		: bodb_NAP
 *  
 * Revisions:
	- 20180925@Helen: GET CODES FROM PRO + DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	     
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
		uf.Policy,
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
		(
			SELECT
				CASE 
					WHEN ISNULL(A.FunctionID, 0) = 0 THEN B.FunctionID 
					ELSE A.FunctionID 
				END AS FunctionID,
				CASE 
					WHEN ISNULL(A.Policy, 0) < ISNULL(B.Policy, 0) THEN ISNULL(B.Policy, 0) 
					ELSE ISNULL(A.Policy, 0) 
				END AS Policy
			FROM 
			(
				-- Get function permission of this user in a site
				SELECT FunctionId, Policy
				FROM dbo.NAP_UserFunction WITH (NOLOCK)
				WHERE UserId = @UserId AND SiteId = @SiteId
			) AS A

			FULL OUTER JOIN

			(
				-- Get all function permissino of this group in a site
				SELECT FunctionId, Policy
				FROM dbo.NAP_GroupFunction AS gf WITH (NOLOCK)
					INNER JOIN dbo.NAP_Users AS u WITH (NOLOCK) ON u.GroupId = gf.GroupId
				WHERE u.UserId = @UserId AND gf.SiteId = @SiteId
			) AS B
			ON A.FunctionID = B.FunctionID
		) AS uf
		INNER JOIN dbo.NAP_MenuItems AS m WITH (NOLOCK) ON uf.FunctionId = m.FunctionId AND uf.Policy >= m.Policy
		INNER JOIN dbo.NAP_Functions AS f WITH (NOLOCK) ON uf.FunctionId = f.FunctionId
		INNER JOIN dbo.NAP_Sites AS s WITH (NOLOCK) ON m.SiteId = s.SiteId
		LEFT JOIN CustDB.dbo.custInfo AS cb WITH (NOLOCK) ON m.CreatedBy = cb.custid
		LEFT JOIN CustDB.dbo.custInfo AS mb WITH (NOLOCK) ON m.ModifiedBy = mb.custid
	WHERE 
		(@Environment = 'UAT' OR (@Environment != 'UAT' AND m.Environment = @Environment AND f.Environment = @Environment))
		AND m.IsActive = 1
		AND f.IsActive = 1

END
GO
GRANT EXECUTE ON [dbo].[NAP_MenuItem_GetByUserAndSiteIncludeGroup] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_MenuItem_GetByUserAndSiteIncludeGroup] TO [vnteam] AS [dbo]