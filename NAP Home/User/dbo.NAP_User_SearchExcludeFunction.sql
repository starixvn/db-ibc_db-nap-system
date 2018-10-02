/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_User_SearchExcludeFunction]
    @Username       NVARCHAR(50)
    ,@GroupId       INT
    ,@SiteId        INT
    ,@FunctionId    INT
	,@PageIndex		INT
	,@PageSize		INT
	,@TotalRows		INT	= 0	OUTPUT
AS
/*  
 * Created: 20120820@Edward
 * Task : Search user
 * DB: bodb_NAP
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	
 * Param's Explanation: 
*/
BEGIN

	DECLARE @FirstRec INT, @LastRec INT
	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1
	SELECT @LastRec = ((@PageIndex * @PageSize + 1)) - 1

	SET NOCOUNT ON

	-- gets total rows
	SET @TotalRows = (

	SELECT DISTINCT count(1)
	FROM
		dbo.NAP_Users AS u WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer AS C WITH (NOLOCK) ON u.UserId = c.custid
		LEFT JOIN dbo.NAP_UserSite AS us WITH (NOLOCK) ON u.UserId = us.UserId
	WHERE
		((@SiteId = 0 AND u.UserId NOT IN (SELECT DISTINCT UserId FROM dbo.NAP_UserSite WITH (NOLOCK))) OR (@SiteId != 0 AND us.SiteId = @SiteId))
		AND (@GroupId = 0 OR (@GroupId != 0 AND u.GroupId = @GroupId))
		AND c.username LIKE '%' + @Username + '%'
		AND u.UserId NOT IN (
			SELECT UserId 
			FROM dbo.NAP_UserFunction WITH (NOLOCK) 
			WHERE FunctionId = @FunctionId AND us.SiteId = @SiteId AND Policy > 0
		)
	)

	-- gets data
	SELECT TOP (@PageSize) *
	FROM (
			SELECT DISTINCT us.[Level]
						  , u.UserId
						  , c.firstname
						  , c.lastname
						  , c.email
						  , c.username
						  , c.userpwd
						  , us.LastLoginDate
						  , u.CreatedDate
						  , u.ModifiedDate
						  , g.GroupId
						  , g.GroupName
						  , c1.custid AS CreatorId
						  , c1.username AS CreatorUsername
						  , c2.custid AS ModifierId
						  , c2.username AS ModifierUsername
						  , us.IsActive
						  , us.LastLoginDate AS LastLoginDateUserSite
						  , us.CreatedBy AS CreatorIdUserSite
						  , c3.username AS CreatorUsernameUserSite
						  , us.ModifiedBy AS ModifierIdUserSite
						  , c4.username AS ModifierUsernameUserSite
						  , us.CreatedDate AS CreatedDateUserSite
						  , us.ModifiedDate AS ModifiedDateUserSite
						  , us.SiteId
						  , s.SiteName
						  , row_number() OVER (ORDER BY us.IsActive DESC, us.[Level] DESC) AS num
			FROM
				dbo.NAP_Users AS u WITH (NOLOCK)
				INNER JOIN CustDB.dbo.Customer AS C WITH (NOLOCK)
					ON u.UserId = c.custid
				LEFT JOIN dbo.NAP_Groups AS g WITH (NOLOCK)
					ON g.GroupId = u.GroupId
				LEFT JOIN CustDB.dbo.Customer AS c1 WITH (NOLOCK)
					ON u.CreatedBy = c1.custid
				LEFT JOIN CustDB.dbo.Customer AS c2 WITH (NOLOCK)
					ON u.ModifiedBy = c2.custid
				LEFT JOIN dbo.NAP_UserSite AS us WITH (NOLOCK)
					ON u.UserId = us.UserId
				LEFT JOIN CustDB.dbo.Customer AS c3 WITH (NOLOCK)
					ON us.CreatedBy = c3.custid
				LEFT JOIN CustDB.dbo.Customer AS c4 WITH (NOLOCK)
					ON us.ModifiedBy = c4.custid
				LEFT JOIN dbo.NAP_Sites AS s WITH (NOLOCK)
					ON us.SiteId = s.SiteId
			WHERE
				((@SiteId = 0 AND u.UserId NOT IN (SELECT DISTINCT UserId FROM dbo.NAP_UserSite WITH (NOLOCK))) OR (@SiteId != 0 AND us.SiteId = @SiteId))
				AND (@GroupId = 0 OR (@GroupId != 0 AND u.GroupId = @GroupId))
				AND c.username LIKE '%' + @Username + '%'
				AND u.UserId NOT IN (
					SELECT UserId FROM dbo.NAP_UserFunction WITH (NOLOCK) 
					WHERE FunctionId = @FunctionId AND us.SiteId = @SiteId AND Policy > 0)
		) AS Temp
	WHERE
		Temp.num >= @FirstRec
		AND Temp.num <= @LastRec
	ORDER BY
		Temp.num

END


GO
GRANT EXECUTE ON [dbo].[NAP_User_SearchExcludeFunction] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_SearchExcludeFunction] TO [vnteam] AS [dbo]