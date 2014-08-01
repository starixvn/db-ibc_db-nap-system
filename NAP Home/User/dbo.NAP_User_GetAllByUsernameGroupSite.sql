USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_User_GetAllByUsernameGroupSite]    Script Date: 8/1/2014 1:48:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_User_GetAllByUsernameGroupSite]
    @Username       NVARCHAR(50)
    ,@GroupId       INT
    ,@Site			NVARCHAR(MAX)	= ''
	,@PageIndex		INT
	,@PageSize		INT
	,@TotalRows		INT				= 0	OUTPUT
AS
/*  
 * Created: 20120820@Edward
 * Task : Search user
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
	- @Site : '<ROOT><Site SiteId="4"></Site></ROOT>'  
*/
BEGIN

	-- Read information from @Site and insert into temp table
	DECLARE @TableSite TABLE(SiteId INT)
   
	IF(@Site != '')
		BEGIN
			DECLARE @DocHandle int

			EXEC sp_xml_preparedocument @DocHandle OUTPUT, @Site

			INSERT INTO @TableSite (SiteId)	
			SELECT Data.SiteId
			FROM OPENXML (@DocHandle, '/ROOT/Site',1) 
			WITH ( SiteId INT) AS Data

			EXEC sp_xml_removedocument @DocHandle    
		END

	-- get data
	DECLARE @FirstRec INT, @LastRec INT
	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1
	SELECT @LastRec = ((@PageIndex * @PageSize + 1)) - 1

	SET NOCOUNT ON

	-- gets total rows
	SET @TotalRows = (

	SELECT DISTINCT count(1)
	FROM
		dbo.Users AS u WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Customer AS C WITH (NOLOCK) ON u.UserId = c.custid
		LEFT JOIN dbo.UserSite AS us WITH (NOLOCK) ON u.UserId = us.UserId
	WHERE
		((@Site = '' AND u.UserId NOT IN (SELECT DISTINCT UserId FROM UserSite WITH (NOLOCK))) 
			OR (@Site != '' AND (us.SiteId IN (SELECT SiteId
							FROM @TableSite ) OR us.SiteId IS NULL )))		
		AND (@GroupId = 0 OR (@GroupId != 0 AND u.GroupId = @GroupId))
		AND c.username LIKE '%' + @Username + '%'
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
						  , row_number() OVER (ORDER BY us.IsActive DESC,C.username,s.SiteName, us.[Level] DESC) AS num
			FROM
				dbo.Users AS u WITH (NOLOCK)
				INNER JOIN bodb02.dbo.Customer AS C WITH (NOLOCK)
					ON u.UserId = c.custid
				LEFT JOIN dbo.Groups AS g WITH (NOLOCK)
					ON g.GroupId = u.GroupId
				LEFT JOIN bodb02.dbo.Customer AS c1 WITH (NOLOCK)
					ON u.CreatedBy = c1.custid
				LEFT JOIN bodb02.dbo.Customer AS c2 WITH (NOLOCK)
					ON u.ModifiedBy = c2.custid
				LEFT JOIN dbo.UserSite AS us WITH (NOLOCK)
					ON u.UserId = us.UserId
				LEFT JOIN bodb02.dbo.Customer AS c3 WITH (NOLOCK)
					ON us.CreatedBy = c3.custid
				LEFT JOIN bodb02.dbo.Customer AS c4 WITH (NOLOCK)
					ON us.ModifiedBy = c4.custid
				LEFT JOIN Sites AS s WITH(NOLOCK)
					ON us.SiteId=s.SiteId
			WHERE	
				((@Site = '' AND u.UserId NOT IN (SELECT DISTINCT UserId FROM UserSite WITH (NOLOCK))) 
					OR (@Site != '' AND (us.SiteId IN (SELECT SiteId
														FROM @TableSite ) OR us.SiteId IS NULL)))
				AND (@GroupId = 0 OR (@GroupId != 0 AND u.GroupId = @GroupId))
				AND c.username LIKE '%' + @Username + '%'
		) AS Temp
	WHERE
		Temp.num >= @FirstRec
		AND Temp.num <= @LastRec
	ORDER BY
		Temp.num

END

GO
GRANT EXECUTE ON [dbo].[NAP_User_GetAllByUsernameGroupSite] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_GetAllByUsernameGroupSite] TO [vnteam] AS [dbo]