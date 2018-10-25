/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Task_NAP_RevokeUserPermission]
AS

/*
	Created: 20160809@Harrison
	Task: Revoke user permission
	DB: DBNAP.bodb_NAP

	Revisions:
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
		
	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logObjectId	INT
		,@logDate		DATETIME
		,@logSPData		VARCHAR(5000)
		,@logSPDataOld	VARCHAR(5000)

	DECLARE @xmlTableTemp TABLE(
		id		INT IDENTITY(1,1)
		,userId INT
		,data	VARCHAR(5000))

	SET @logDate = GETDATE()
	SET @startRun = GETDATE()

	INSERT INTO @xmlTableTemp
	SELECT
		TempUsers.UserId AS userId
		,REPLACE(CONVERT(NVARCHAR(MAX), (
			SELECT(
				SELECT
					us.SiteId AS '@si'
					,s.SiteName AS '@s'
				FROM 
					dbo.NAP_UserSite AS us WITH (NOLOCK) 
					INNER JOIN CustDB.dbo.custInfo AS u WITH (NOLOCK) ON u.custid = us.UserId
					INNER JOIN dbo.NAP_Sites AS s WITH (NOLOCK) ON s.SiteId = us.SiteId
				WHERE 
					us.ExpiredDate IS NOT NULL 
					AND us.ExpiredDate < CONVERT(DATE, SWITCHOFFSET(SYSDATETIMEOFFSET(), '+07:00'))
					AND us.IsNeverExpired = 0
					AND us.UserId = TempUsers.UserId
					FOR XML PATH('z'), TYPE)
			FOR XML PATH('r'), TYPE)
		), '" />', '"/"') AS data
	FROM 
		(SELECT DISTINCT
			us.UserId AS UserId
		FROM
			dbo.NAP_UserSite AS us WITH (NOLOCK) 
			INNER JOIN CustDB.dbo.custInfo AS u WITH (NOLOCK) ON u.custid = us.UserId
			INNER JOIN dbo.NAP_Sites AS s WITH (NOLOCK) ON s.SiteId = us.SiteId
		WHERE 
			us.ExpiredDate IS NOT NULL 
			AND us.ExpiredDate < CONVERT(DATE, SWITCHOFFSET(SYSDATETIMEOFFSET(), '+07:00'))
			AND us.IsNeverExpired = 0
			AND u.username LIKE 'starix%') AS TempUsers

	-- Revoke User Function permission
	UPDATE uf
	SET 
		uf.Policy = 0
		,uf.ModifiedBy = 8
		,uf.ModifiedDate = GETDATE()
	FROM 
		dbo.NAP_UserFunction AS uf  WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.NAP_UserSite AS us WITH (NOLOCK)
		ON	us.SiteId = uf.SiteId 
			AND us.UserId = uf.UserId
		INNER JOIN CustDB.dbo.custInfo AS u WITH (NOLOCK) ON u.custid = uf.UserId
	WHERE
		us.ExpiredDate IS NOT NULL
		AND us.ExpiredDate < CONVERT(DATE, SWITCHOFFSET(SYSDATETIMEOFFSET(), '+07:00')) 
		AND us.IsNeverExpired = 0
		AND u.username LIKE 'starix%'

	-- Revoke User Site permission
	UPDATE us
	SET
		us.IsActive = 0
		,us.IsNeverExpired = 1
	FROM 
		dbo.NAP_UserSite AS us WITH (ROWLOCK, UPDLOCK)
		INNER JOIN CustDB.dbo.custInfo AS u WITH (NOLOCK) ON u.custid = us.UserId
	WHERE 
		us.ExpiredDate IS NOT NULL 
		AND us.ExpiredDate < CONVERT(DATE, SWITCHOFFSET(SYSDATETIMEOFFSET(), '+07:00'))
		AND us.IsNeverExpired = 0
		AND u.username LIKE 'starix%'
	
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	-- Write log for each user
	DECLARE	@rowNum		INT
		, @maxRowNum	INT

	SELECT
		@maxRowNum = COUNT(*)
		,@rowNum = 1 
	FROM @xmlTableTemp

	WHILE @rowNum <= @maxRowNum
	BEGIN
		SELECT 
			@logObjectId = Temp.userId
			,@logSPDataOld = Temp.data 
		FROM @xmlTableTemp AS Temp
		WHERE Temp.id = @rowNum

		EXEC dbo.NAP_RunSP_WriteLog 
			@UserId			= 0,
			@SPName			= 'Task_NAP_RevokeUserPermission',
			@ObjectId		= @logObjectId,
			@ObjectTypeId	= 1,
			@Language		= NULL,
			@SiteID			= 1,
			@IP				= NULL,
			@Date			= @logDate,
			@Data			= @logSPDataOld,
			@OldData		= @logSPDataOld,
			@Duration		= @Duration

		SELECT @rowNum = @rowNum + 1,
			@logObjectId = NULL,
			@logSPDataOld = NULL
	END
END