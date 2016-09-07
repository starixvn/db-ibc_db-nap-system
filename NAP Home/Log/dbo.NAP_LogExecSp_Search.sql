USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_LogExecSp_Search]    Script Date: 8/1/2014 1:39:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_LogExecSp_Search]
	@Username		NVARCHAR(50)	= ''
	,@Name			NVARCHAR(50)	= ''
	,@FilterType	INT
	,@From			DATETIME
	,@To			DATETIME
	,@PageIndex		INT
	,@PageSize		INT
	,@TotalRows		INT				= 0	OUTPUT	
AS

/*
	Created: 20120820@Edward
	Task: Search execute SP log
	DB: DBNAP.bodb_NAP

	Revisions:
		- 20160426@Kos: Support log of revoke permission task

	Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FirstRec	INT,
		@LastRec		INT

	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1
	SELECT @LastRec = ((@PageIndex * @PageSize + 1)) - 1


	IF @FilterType = 1	-- User
	BEGIN
		-- gets total rows
		SET @TotalRows = (
			SELECT COUNT(1)
			FROM
				bodb_NAPLog.dbo.NAPLog_RUNSP AS lg WITH (NOLOCK)
				INNER JOIN Users AS u WITH (NOLOCK) ON lg.ObjectId = u.UserId
				INNER JOIN bodb02.dbo.custInfo AS cu WITH (NOLOCK) ON u.UserId = cu.custid
				INNER JOIN bodb02.dbo.custInfo AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.custid
				INNER JOIN bodb_NAPLog.dbo.NAPLog_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
			WHERE 
				lg.ObjectTypeId = 1 -- Object type : User
				AND cu.username LIKE '%' + @Name + '%'
				AND lg.LogDate BETWEEN @From AND @To
				AND cu1.username LIKE '%' + @Username + '%'
		)

		SET @TotalRows += (
			SELECT COUNT(1)
			FROM 
				bodb_NAPLog.dbo.NAPLog_RUNSP AS lg WITH (NOLOCK)
				INNER JOIN bodb_NAPLog.dbo.NAPLog_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
				INNER JOIN Users AS u WITH (NOLOCK) ON lg.ObjectId = u.UserId
				INNER JOIN bodb02.dbo.custInfo AS cu WITH (NOLOCK) ON u.UserId = cu.custid
			WHERE 
				lg.ObjectTypeId = 1 -- Object type : User
				AND lg.LogDate BETWEEN @From AND @To
				AND lg.SPName LIKE 'Task%'
				AND cu.username LIKE '%' + @Name + '%'
				AND (@Username LIKE 'sys%' OR @Username = '')
		)

		-- gets data
		SELECT TOP (@PageSize) *
		FROM (
				SELECT
					SubTemp.Id
					,SubTemp.LogDate
					,SubTemp.Name
					,SubTemp.Modifier 
					,SubTemp.ActionId
					,SubTemp.ActionName
					,ROW_NUMBER() OVER (ORDER BY SubTemp.LogDate DESC) AS num
				FROM (
					SELECT 
						lg.Id,
						lg.LogDate,
						cu.username AS Name,
						cu1.username AS Modifier,
						la.ActionId,
						la.ActionName
					FROM 
						bodb_NAPLog.dbo.NAPLog_RUNSP AS lg WITH (NOLOCK)
						INNER JOIN Users AS u WITH (NOLOCK) ON lg.ObjectId = u.UserId
						INNER JOIN bodb02.dbo.custInfo AS cu WITH (NOLOCK) ON u.UserId = cu.custid
						INNER JOIN bodb02.dbo.custInfo AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.custid
						INNER JOIN bodb_NAPLog.dbo.NAPLog_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
					WHERE 
						lg.ObjectTypeId = 1
						AND cu.username LIKE '%' + @Name + '%'
						AND lg.LogDate BETWEEN @From AND @To
						AND cu1.username LIKE '%' + @Username + '%'
					UNION
					SELECT
						lg.Id,
						lg.LogDate,
						cu.username AS Name,
						'System' AS Modifier,
						la.ActionId,
						la.ActionName
					FROM 
						bodb_NAPLog.dbo.NAPLog_RUNSP AS lg WITH (NOLOCK)
						INNER JOIN bodb_NAPLog.dbo.NAPLog_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
						INNER JOIN Users AS u WITH (NOLOCK) ON lg.ObjectId = u.UserId
						INNER JOIN bodb02.dbo.custInfo AS cu WITH (NOLOCK) ON u.UserId = cu.custid
					WHERE 
						lg.ObjectTypeId = 1
						AND lg.LogDate BETWEEN @From AND @To
						AND lg.SPName LIKE 'Task%'
						AND cu.username LIKE '%' + @Name + '%'
						AND (@Username LIKE 'sys%' OR @Username = '')
					) AS SubTemp
			) AS Temp
		WHERE
			Temp.num >= @FirstRec
			AND Temp.num <= @LastRec
		ORDER BY
			Temp.num
	END 

	IF @FilterType = 2 -- Group
	BEGIN
		-- gets total rows
		SET @TotalRows = (
			SELECT COUNT(1)
			FROM 
				bodb_NAPLog.dbo.NAPLog_RUNSP AS lg WITH(NOLOCK)
				INNER JOIN Groups AS g WITH(NOLOCK) ON lg.ObjectId = g.GroupId
				INNER JOIN bodb02.dbo.custInfo AS cu1 WITH(NOLOCK) ON lg.UserId = cu1.custid
				INNER JOIN bodb_NAPLog.dbo.NAPLog_Action AS la WITH(NOLOCK) ON lg.ActionId = la.ActionId
			WHERE 
				lg.ObjectTypeId = 2
				AND g.GroupName LIKE '%' + @Name + '%'
				AND lg.LogDate BETWEEN @From AND @To
				AND cu1.username LIKE '%' + @Username + '%'
		)

		-- gets data
		SELECT TOP (@PageSize) *
		FROM (
				SELECT 
					lg.Id,
					lg.LogDate,
					g.GroupName AS Name,
					cu1.username AS Modifier,
					la.ActionId,
					la.ActionName,
					ROW_NUMBER() OVER (ORDER BY lg.LogDate DESC) AS num
				FROM 
					bodb_NAPLog.dbo.NAPLog_RUNSP AS lg WITH(NOLOCK)
					INNER JOIN Groups AS g WITH(NOLOCK) ON lg.ObjectId = g.GroupId
					INNER JOIN bodb02.dbo.custInfo AS cu1 WITH(NOLOCK) ON lg.UserId = cu1.custid
					INNER JOIN bodb_NAPLog.dbo.NAPLog_Action AS la WITH(NOLOCK) ON lg.ActionId = la.ActionId
				WHERE 
					lg.ObjectTypeId = 2
					AND g.GroupName LIKE '%' + @Name + '%'
					AND lg.LogDate BETWEEN @From AND @To
					AND cu1.username LIKE '%' + @Username + '%'
			) AS Temp
		WHERE
			Temp.num >= @FirstRec
			AND Temp.num <= @LastRec
		ORDER BY
			Temp.num
	END

	IF @FilterType = 3 -- Site
	BEGIN
		-- gets total rows
		SET @TotalRows = (
			SELECT COUNT(1)
			FROM 
				bodb_NAPLog.dbo.NAPLog_RUNSP AS lg WITH (NOLOCK)
				INNER JOIN Sites AS s WITH (NOLOCK) ON lg.ObjectId = s.SiteId
				INNER JOIN bodb02.dbo.custInfo AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.custid
				INNER JOIN bodb_NAPLog.dbo.NAPLog_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
			WHERE 
				lg.ObjectTypeId = 3
				AND s.SiteName LIKE '%' + @Name + '%'
				AND lg.LogDate BETWEEN @From AND @To
				AND cu1.username LIKE '%' + @Username + '%'
		)

		-- gets data
		SELECT TOP (@PageSize) *
		FROM (
				SELECT 
					lg.Id,
					lg.LogDate,
					s.SiteName AS Name,
					cu1.username AS Modifier,
					la.ActionId,
					la.ActionName,
					row_number() OVER (ORDER BY lg.LogDate DESC) AS num
				FROM 
					bodb_NAPLog.dbo.NAPLog_RUNSP AS lg WITH (NOLOCK)
					INNER JOIN Sites AS s WITH (NOLOCK) ON lg.ObjectId = s.SiteId
					INNER JOIN bodb02.dbo.custInfo AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.custid
					INNER JOIN bodb_NAPLog.dbo.NAPLog_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
				WHERE 
					lg.ObjectTypeId = 3
					AND s.SiteName LIKE '%' + @Name + '%'
					AND lg.LogDate BETWEEN @From AND @To
					AND cu1.username LIKE '%' + @Username + '%'
			) AS Temp
		WHERE
			Temp.num >= @FirstRec
			AND Temp.num <= @LastRec
		ORDER BY
			Temp.num
	END

	IF @FilterType = 4	-- Function
	BEGIN
		-- gets total rows
		SET @TotalRows = (
			SELECT COUNT(1)
			FROM 
				bodb_NAPLog.dbo.NAPLog_RUNSP AS lg WITH (NOLOCK)
				INNER JOIN Functions AS f WITH (NOLOCK) ON lg.ObjectId = f.FunctionId
				INNER JOIN bodb02.dbo.custInfo AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.custid
				INNER JOIN bodb_NAPLog.dbo.NAPLog_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
			WHERE 
				lg.ObjectTypeId = 4
				AND f.FunctionName LIKE '%' + @Name + '%'
				AND lg.LogDate BETWEEN @From AND @To
				AND cu1.username LIKE '%' + @Username + '%'
		)

		-- gets data
		SELECT TOP (@PageSize) *
		FROM (
				SELECT 
					lg.Id,
					lg.LogDate,
					f.FunctionName AS Name,
					cu1.username AS Modifier,
					la.ActionId,
					la.ActionName,
					row_number() OVER (ORDER BY lg.LogDate DESC) AS num
				FROM 
					bodb_NAPLog.dbo.NAPLog_RUNSP AS lg WITH (NOLOCK)
					INNER JOIN Functions AS f WITH (NOLOCK) ON lg.ObjectId = f.FunctionId
					INNER JOIN bodb02.dbo.custInfo AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.custid
					INNER JOIN bodb_NAPLog.dbo.NAPLog_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
				WHERE 
					lg.ObjectTypeId = 4 -- Object type : Function
					AND f.FunctionName LIKE '%' + @Name + '%'
					AND lg.LogDate BETWEEN @From AND @To
					AND cu1.username LIKE '%' + @Username + '%'
			) AS Temp
		WHERE
			Temp.num >= @FirstRec
			AND Temp.num <= @LastRec
		ORDER BY
			Temp.num
	END

	IF @FilterType = 5 -- Menu item
	BEGIN
		-- gets total rows
		SET @TotalRows = (
			SELECT COUNT(1)
			FROM 
				bodb_NAPLog.dbo.NAPLog_RUNSP AS lg WITH (NOLOCK)
				INNER JOIN MenuItems AS m WITH (NOLOCK) ON lg.ObjectId = m.MenuItemId
				INNER JOIN bodb02.dbo.custInfo AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.custid
				INNER JOIN bodb_NAPLog.dbo.NAPLog_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
			WHERE 
				lg.ObjectTypeId = 5
				AND m.MenuItemName LIKE '%' + @Name + '%'
				AND lg.LogDate BETWEEN @From AND @To
				AND cu1.username LIKE '%' + @Username + '%'
		)

		-- gets data
		SELECT TOP (@PageSize) *
		FROM (
				SELECT 
					lg.Id,
					lg.LogDate,
					m.MenuItemName AS Name,
					cu1.username AS Modifier,
					la.ActionId,
					la.ActionName,
					row_number() OVER (ORDER BY lg.LogDate DESC) AS num
				FROM 
					bodb_NAPLog.dbo.NAPLog_RUNSP AS lg WITH (NOLOCK)
					INNER JOIN MenuItems AS m WITH (NOLOCK) ON lg.ObjectId = m.MenuItemId
					INNER JOIN bodb02.dbo.custInfo AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.custid
					INNER JOIN bodb_NAPLog.dbo.NAPLog_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
				WHERE 
					lg.ObjectTypeId = 5 -- Object type : menu item
					AND m.MenuItemName LIKE '%' + @Name + '%'
					AND lg.LogDate BETWEEN @From AND @To
					AND cu1.username LIKE '%' + @Username + '%'
			) AS Temp
		WHERE
			Temp.num >= @FirstRec
			AND Temp.num <= @LastRec
		ORDER BY
			Temp.num
	END
END

GO
GRANT EXECUTE ON [dbo].[NAP_LogExecSp_Search] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_LogExecSp_Search] TO [vnteam] AS [dbo]