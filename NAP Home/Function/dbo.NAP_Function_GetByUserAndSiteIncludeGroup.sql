/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Function_GetByUserAndSiteIncludeGroup]
	@UserId			INT,				
	@SiteId			INT,				
	@Environment	VARCHAR(10)	= 'UAT'	-- 'UAT', 'LIVE'
AS

/*
	Created: 20120810@Kos
	Task : Get all function permission of a user in a site include its group permission
	DB: DBPOL-NAP_UserControl

	Revisions:     
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	Param's Explanation: 
*/
BEGIN
	SET NOCOUNT ON

	SELECT 
		uf.FunctionId,
		f.FunctionName,	
		f.FunctionKey,	
		uf.Policy,
		f.Description,	
		f.CRUD,
		f.DisplayOrder,
		f.IsActive,
		f.Environment,	
		f.ParentId,			-- parent information
		f.ParentName,
		f.SiteId,			-- site information
		s.SiteName
	FROM 
		(
			-- Select function permission of user in site and include its group function
			-- get highest policy in one function
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
				-- Get function permission of @UserId in @SiteId
				SELECT uf.FunctionId, uf.Policy
				FROM 
					dbo.NAP_UserFunction AS uf WITH (NOLOCK)
					INNER JOIN dbo.NAP_Functions AS f WITH (NOLOCK) ON uf.FunctionId = f.FunctionId
				WHERE 
					uf.UserId = @UserId 
					AND uf.SiteId = @SiteId
					AND f.IsActive = 1
			) AS A
			FULL OUTER JOIN
			(
				-- Get function permission of group where user belong to
				SELECT gf.FunctionId, gf.Policy
				FROM 
					dbo.NAP_GroupFunction AS gf WITH (NOLOCK)
					INNER JOIN dbo.NAP_Users AS u WITH (NOLOCK) ON u.GroupId = gf.GroupId
					INNER JOIN dbo.NAP_Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId
				WHERE 
					u.UserId = @UserId
					AND gf.SiteId = @SiteId
					AND f.IsActive = 1
			) AS B
			ON A.FunctionID = B.FunctionID 	
		) AS uf
		LEFT JOIN dbo.NAP_Functions AS f WITH (NOLOCK) ON uf.FunctionId = f.FunctionId
		LEFT JOIN dbo.NAP_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
	WHERE 
		(@Environment = 'UAT' OR (@Environment != 'UAT' AND f.Environment = @Environment))
		AND f.IsActive = 1
END

GO
GRANT EXECUTE ON [dbo].[NAP_Function_GetByUserAndSiteIncludeGroup] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_GetByUserAndSiteIncludeGroup] TO [vnteam] AS [dbo]