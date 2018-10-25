/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Function_GetByGroup]
	@GroupId		INT,				
	@Environment	VARCHAR(10)	= 'UAT'	-- 'UAT', 'LIVE'
AS

/*
	Created: 20120810@Kos
	Task :	Get all function permission of a group
				and return list of function include policy
	DB: DBPOL/NAP_UserControl
	  
	Revisions:    
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
		 
	Param's Explanation: 
		• @GroupId		:	Get function permission of this group
		• @Environment	:	UAT or LIVE
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
		dbo.NAP_GroupFunction AS gf WITH (NOLOCK)
		INNER JOIN dbo.NAP_Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId
		INNER JOIN dbo.NAP_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		LEFT JOIN CUSTDB.dbo.custInfo AS cb WITH (NOLOCK) ON gf.CreatedBy = cb.custid
		LEFT JOIN CUSTDB.dbo.custInfo AS mb WITH (NOLOCK) ON gf.ModifiedBy = mb.custid
	WHERE 
		gf.GroupId = @GroupId
		AND f.IsActive = 1 AND s.IsActive = 1 -- check with site is active
		AND (@Environment = 'UAT' OR (@Environment != 'UAT' AND f.Environment = @Environment))
END


GO
GRANT EXECUTE ON [dbo].[NAP_Function_GetByGroup] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_GetByGroup] TO [vnteam] AS [dbo]