/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Function_GetById]
	@FunctionId INT
AS
/*
	Created	: 20120810@Kos
	Task	: Get function information by function ID
	DB		: DBPOL/NAP_UserControl

	Revisions:     
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	Param's Explanation: 
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
		dbo.NAP_Functions AS f WITH (NOLOCK)
		INNER JOIN dbo.NAP_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		LEFT JOIN CUSTDB.dbo.custInfo AS cb WITH (NOLOCK) ON f.CreatedBy = cb.custid
		LEFT JOIN CUSTDB.dbo.custInfo AS mb WITH (NOLOCK) ON f.ModifiedBy = mb.custid
	WHERE f.FunctionId = @FunctionId
END

GO
GRANT EXECUTE ON [dbo].[NAP_Function_GetById] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_GetById] TO [vnteam] AS [dbo]