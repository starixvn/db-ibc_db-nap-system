/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_User_GetAllByUsernameGroupSite]
	@Username		NVARCHAR(50),
	@GroupId		INT,
	@Site			NVARCHAR(MAX)	= N'',
	@Status			TINYINT			= 0,
	@Environment	VARCHAR(10)		= 'UAT',	-- 'UAT', 'LIVE'
	@PageIndex		INT,
	@PageSize		INT,
	@TotalRows		INT				= 0	OUTPUT
AS

/*
	Created: 20120820@Edward
	Task: Search user
	DB: DBNAP.bodb_NAP
	Revisions:
		- 20171124@Kos: Add param @Status, @Environment [Redmine: #87124]
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
		
	Param's Explanation:
		- @Username: Username search text
		- @GroupId: User group ID (0: All groups, Others: specific group)
		- @Site : '<ROOT><Site SiteId="4"></Site></ROOT>'
		- @Status: Status (0: All, 1: Active, 2: Inactive, 3: Closed)
*/

BEGIN
	SET NOCOUNT ON

	-- Read information from @Site and insert into temp table
	DECLARE @TableSite TABLE (SiteId INT)

	IF @Site <> ''
	BEGIN
		DECLARE @DocHandle INT

		EXEC sp_xml_preparedocument @DocHandle OUTPUT, @Site

		INSERT INTO @TableSite (SiteId)
		SELECT Data.SiteId
		FROM OPENXML (@DocHandle, '/ROOT/Site', 1)
		WITH (SiteId INT) AS Data

		EXEC sp_xml_removedocument @DocHandle
	END

	DECLARE @Users TABLE (
		UserId		INT,
		Username	NVARCHAR(50),
		Closed		BIT
	)

	INSERT INTO @Users
	SELECT
		u.UserId,
		c.username,
		c.closed
	FROM dbo.NAP_Users AS u WITH (NOLOCK)
		INNER JOIN CustDB.dbo.custInfo AS c WITH (NOLOCK) ON u.UserId = c.custid
	WHERE @GroupId = 0
		OR (@GroupId <> 0 AND u.GroupId = @GroupId)

	DELETE @Users
	WHERE username NOT LIKE '%' + @Username + '%'
		OR (@Status IN (1, 2) AND closed <> 0)
		OR (@Status = 3 AND closed <> 1)

	DECLARE @UserSite TABLE (
		UserId		INT,
		SiteId		INT,
		IsActive	BIT,
		Level		INT
	)

	INSERT INTO @UserSite
	SELECT
		us.UserId,
		us.SiteId,
		us.IsActive,
		us.Level
	FROM dbo.NAP_UserSite AS us WITH (NOLOCK)
	WHERE EXISTS ( SELECT 1 FROM @TableSite WHERE SiteId = us.SiteId )
		AND ((@Status = 1 AND us.IsActive = 1)
			OR (@Status = 2 AND us.IsActive = 0)
			OR @Status IN (0, 3))

	-- Get total rows
	DECLARE @FirstRec INT,
		@LastRec INT

	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1
	SELECT @LastRec = @PageIndex * @PageSize

	IF @Status IN (0, 3)
	BEGIN
		SET @TotalRows = (
			SELECT DISTINCT COUNT(1)
			FROM @Users AS u
				LEFT JOIN @UserSite AS us ON u.UserId = us.UserId
			WHERE @Site <> ''
				OR (@Site = '' AND NOT EXISTS ( SELECT 1 FROM @UserSite WHERE UserId = u.UserId ))
		)
	END
	ELSE IF @Status IN (1, 2)
	BEGIN
		SET @TotalRows = (
			SELECT DISTINCT COUNT(1)
			FROM @Users AS u
				INNER JOIN @UserSite AS us ON u.UserId = us.UserId
			WHERE @Site <> ''
				OR (@Site = '' AND NOT EXISTS ( SELECT 1 FROM @UserSite WHERE UserId = u.UserId ))
		)
	END

	-- Gets data
	DECLARE @UserSiteStatus TABLE (
		UserId	INT,
		SiteId	TINYINT,
		Closed	BIT,
		RowNum	INT
	)

	IF @Status IN (0, 3)
	BEGIN
		INSERT INTO @UserSiteStatus
		SELECT TOP(@PageSize)
			Temp.UserId,
			Temp.SiteId,
			Temp.closed,
			Temp.RowNum
		FROM (
				SELECT DISTINCT
					u.UserId,
					us.SiteId,
					u.closed,
					ROW_NUMBER() OVER (ORDER BY u.closed ASC, us.IsActive DESC, u.username, s.SiteName, us.[Level] DESC) AS RowNum
				FROM @Users AS u
					LEFT JOIN @UserSite AS us ON u.UserId = us.UserId
					LEFT JOIN dbo.NAP_Sites AS s WITH (NOLOCK) ON us.SiteId = s.SiteId
				WHERE @Site <> ''
					OR (@Site = '' AND NOT EXISTS (SELECT 1 FROM @UserSite WHERE UserId = u.UserId))
			) AS Temp
		WHERE Temp.RowNum BETWEEN @FirstRec AND @LastRec
		ORDER BY Temp.RowNum
	END
	ELSE IF @Status IN (1, 2)
	BEGIN
		INSERT INTO @UserSiteStatus
		SELECT TOP(@PageSize)
			Temp.UserId,
			Temp.SiteId,
			Temp.closed,
			Temp.RowNum
		FROM (
				SELECT DISTINCT
					u.UserId,
					us.SiteId,
					u.closed,
					ROW_NUMBER() OVER (ORDER BY u.closed ASC, us.IsActive DESC, u.username, s.SiteName, us.[Level] DESC) AS RowNum
				FROM @Users AS u
					INNER JOIN @UserSite AS us ON u.UserId = us.UserId
					INNER JOIN dbo.NAP_Sites AS s WITH (NOLOCK) ON us.SiteId = s.SiteId
				WHERE @Site <> ''
					OR (@Site = '' AND NOT EXISTS (SELECT 1 FROM @UserSite WHERE UserId = u.UserId))
			) AS Temp
		WHERE Temp.RowNum BETWEEN @FirstRec AND @LastRec
		ORDER BY Temp.RowNum
	END

	SELECT
		u.UserId,
		c.username,
		g.GroupId,
		g.GroupName,
		us.SiteId,
		s.SiteName,
		us.[Level],
		CASE
			WHEN tmp.Closed = 0 AND us.IsActive = 1 THEN 1
			WHEN tmp.Closed = 0 AND us.IsActive = 0 THEN 2
			WHEN tmp.Closed = 1 THEN 3
		END AS Status,
		c.firstname,
		c.lastname,
		c.email,
		c.userpwd,
		us.LastLoginDate,
		u.CreatedDate,
		u.ModifiedDate,
		c1.custid AS CreatorId,
		c1.username AS CreatorUsername,
		c2.custid AS ModifierId,
		c2.username AS ModifierUsername,
		us.LastLoginDate AS LastLoginDateUserSite,
		us.CreatedBy AS CreatorIdUserSite,
		c3.username AS CreatorUsernameUserSite,
		us.ModifiedBy AS ModifierIdUserSite,
		c4.username AS ModifierUsernameUserSite,
		us.CreatedDate AS CreatedDateUserSite,
		us.ModifiedDate AS ModifiedDateUserSite
	FROM
		@UserSiteStatus AS tmp
		INNER JOIN dbo.NAP_Users AS u WITH (NOLOCK) ON tmp.UserId = u.UserId
		INNER JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON u.UserId = c.custid
		LEFT JOIN dbo.NAP_Groups AS g WITH (NOLOCK) ON g.GroupId = u.GroupId
		LEFT JOIN CustDB.dbo.Customer AS c1 WITH (NOLOCK) ON u.CreatedBy = c1.custid
		LEFT JOIN CustDB.dbo.Customer AS c2 WITH (NOLOCK) ON u.ModifiedBy = c2.custid
		LEFT JOIN dbo.NAP_UserSite AS us WITH (NOLOCK) ON tmp.UserId = us.UserId AND tmp.SiteId = us.SiteId
		LEFT JOIN CustDB.dbo.Customer AS c3 WITH (NOLOCK) ON us.CreatedBy = c3.custid
		LEFT JOIN CustDB.dbo.Customer AS c4 WITH (NOLOCK) ON us.ModifiedBy = c4.custid
		LEFT JOIN dbo.NAP_Sites AS s WITH (NOLOCK) ON tmp.SiteId = s.SiteId
	ORDER BY tmp.RowNum
END

GO
GRANT EXECUTE ON [dbo].[NAP_User_GetAllByUsernameGroupSite] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_GetAllByUsernameGroupSite] TO [vnteam] AS [dbo]
GO
