/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_Function_CopyPermission]
	@FromFunctionId	INT,
	@ToFunctionId	INT,
	@SiteId			INT,
	@Environment	VARCHAR(10)		= 'UAT',	-- 'UAT', 'LIVE'
	@ModifiedBy		INT,
	@ModifiedDate	DATETIME,
	@CurrentUserId	INT,
	@CurrentSiteId	INT,
	@LogDate		DATETIME,
	@LoginIP		VARCHAR(30)		= '',
	@Language		VARCHAR(20)		= 'en-us',
	@ErrCode		INT				= 0			OUTPUT,
	@ErrMsg			NVARCHAR(1000)	= ''		OUTPUT
AS

/*
	Created: 20181231@Kos
	Task: Duplicate a function
	DB: DBPOL.NAP_UserControl

	Revisions:
		- 20181231@Kos : Create [Redmine: #104379]

	Param's Explanation:
*/

BEGIN

	SET NOCOUNT ON

	-- For write log
	DECLARE
		@now			DATETIME,
		@startRun		DATETIME,
		@endRun			DATETIME,
		@duration		INT,
		@logSPData		VARCHAR(5000),
		@logSPDataOld	VARCHAR(5000),
		@xml			XML,
		@FromCRUD		TINYINT,
		@ToCRUD			TINYINT,
		@ToParentId		SMALLINT

	SELECT @FromCRUD = CRUD
	FROM dbo.NAP_Functions WITH (NOLOCK)
	WHERE FunctionId = @FromFunctionId

	SELECT
		@ToCRUD = CRUD,
		@ToParentId = ParentId
	FROM dbo.NAP_Functions WITH (NOLOCK)
	WHERE FunctionId = @ToFunctionId

	-- Copy permission for parent function
	IF @ToParentId IS NOT NULL AND @ToParentId <> 0
	BEGIN
		EXEC dbo.NAP_Function_CopyPermission
			@FromFunctionId = @FromFunctionId,
			@ToFunctionId = @ToParentId,
			@SiteId = @SiteId,
			@Environment = @Environment,
			@ModifiedBy = @ModifiedBy,
			@ModifiedDate = @ModifiedDate,
			@CurrentUserId = @CurrentUserId,
			@CurrentSiteId = @CurrentSiteId,
			@LogDate = @LogDate,
			@LoginIP = @LoginIP,
			@Language = @Language,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT
	END

	-- Get users which have diffent permission
	DECLARE @UserDiffFunction TABLE (
		UserId		INT,
		FromPolicy	TINYINT,
		ToPolicy	TINYINT )

	INSERT INTO @UserDiffFunction
	SELECT
		uf1.UserId,
		CASE
			WHEN uf1.Policy = 2 AND @ToCRUD = 0 THEN 1
			ELSE uf1.Policy
		END,
		CASE
			WHEN uf2.Policy = 2 AND @FromCRUD = 0 THEN 1
			ELSE uf2.Policy
		END
	FROM dbo.NAP_UserFunction AS uf1 WITH (NOLOCK)
		INNER JOIN dbo.NAP_UserFunction AS uf2 WITH (NOLOCK) ON uf1.UserId = uf2.UserId
	WHERE uf1.FunctionId = @FromFunctionId
		AND uf2.FunctionId = @ToFunctionId
		AND CASE WHEN uf1.Policy = 2 AND @ToCRUD = 0 THEN 1
				ELSE uf1.Policy
			END <> CASE WHEN uf2.Policy = 2 AND @FromCRUD = 0 THEN 1
				ELSE uf2.Policy
			END

	INSERT INTO @UserDiffFunction
	SELECT
		uf.UserId,
		CASE
			WHEN uf.Policy = 2 AND @ToCRUD = 0 THEN 1
			ELSE uf.Policy
		END,
		NULL
	FROM dbo.NAP_UserFunction AS uf WITH (NOLOCK)
	WHERE uf.FunctionId = @FromFunctionId
		AND uf.Policy <> 0
		AND NOT EXISTS (SELECT 1 FROM dbo.NAP_UserFunction WITH (NOLOCK) WHERE UserId = uf.UserId AND FunctionId = @ToFunctionId)

	INSERT INTO @UserDiffFunction
	SELECT
		uf.UserId,
		0,
		uf.Policy
	FROM dbo.NAP_UserFunction AS uf WITH (NOLOCK)
	WHERE uf.FunctionId = @ToFunctionId
		AND uf.Policy <> 0
		AND NOT EXISTS (SELECT 1 FROM dbo.NAP_UserFunction WITH (NOLOCK) WHERE UserId = uf.UserId AND FunctionId = @FromFunctionId)

	DECLARE @UserFunction TABLE (
		FunctionId	SMALLINT,
		Policy		TINYINT,
		UserId		INT )

	SET @now = GETDATE()
	SET @startRun = @now

	DECLARE
		@UserId		INT,
		@FromPolicy	TINYINT,
		@ToPolicy	TINYINT

	-- Copy permission for one by one user
	WHILE EXISTS (SELECT 1 FROM @UserDiffFunction)
	BEGIN
		SELECT TOP 1
			@UserId = UserId,
			@FromPolicy = FromPolicy,
			@ToPolicy = ToPolicy
		FROM @UserDiffFunction

		DELETE FROM @UserFunction

		INSERT INTO @UserFunction
		SELECT
			FunctionId,
			Policy,
			UserId
		FROM dbo.NAP_UserFunction WITH (NOLOCK)
		WHERE UserId = @UserId AND SiteId = @SiteId

		-- Get log data before update
		SET @xml = (
			SELECT
				@SiteId AS '@s',
				@UserId AS '@u',
				(
					SELECT
						FunctionId AS '@f',
						Policy AS '@p'
					FROM @UserFunction
					FOR XML PATH('z'), TYPE
				)
			FOR XML PATH('r'), TYPE
		)

		SET @logSPDataOld = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')

		-- Copy permission or insert new
		IF @ToPolicy IS NOT NULL
		BEGIN
			UPDATE dbo.NAP_UserFunction WITH (ROWLOCK)
			SET Policy = @FromPolicy
			WHERE UserId = @UserId AND FunctionId = @ToFunctionId
		END
		ELSE
		BEGIN
			INSERT INTO dbo.NAP_UserFunction (UserId, FunctionId, SiteId, Policy, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
			VALUES (@UserId, @ToFunctionId, @SiteId, @FromPolicy, @ModifiedBy, @ModifiedDate, @ModifiedBy, @ModifiedDate)
		END

		--Get log data after update
		SET @xml = (
			SELECT
				@SiteId AS '@s',
				@UserId AS '@u',
				(
					SELECT
						uf.FunctionId AS '@f',
						uf.Policy AS '@p'
					FROM dbo.NAP_UserFunction AS uf WITH (NOLOCK)
						LEFT JOIN @UserFunction AS t ON uf.FunctionId = t.FunctionId AND uf.Policy = t.Policy
					WHERE uf.UserId = @UserId
						AND uf.SiteId = @SiteId
						AND t.UserId IS NULL
					FOR XML PATH('z'), TYPE
				)
			FOR XML PATH('r'), TYPE
		)

		SET @logSPData	= REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')

		SET @endRun		= GETDATE()
		SET @duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)

		EXEC dbo.NAP_RunSP_WriteLog
			@UserId			= @CurrentUserId,
			@SPName			= 'NAP_Function_CopyPermission',
			@ObjectId		= @UserId,
			@ObjectTypeId	= 1,			-- Object type : User
			@Language		= @Language,
			@SiteID			= @CurrentSiteId,
			@IP				= @LoginIP,
			@Date			= @LogDate,
			@Data			= @logSPData,
			@OldData		= @logSPDataOld,
			@Duration		= @Duration

		DELETE FROM @UserDiffFunction WHERE UserId = @UserId
	END
END

GO
GRANT EXECUTE ON [dbo].[NAP_Function_CopyPermission] TO [bodbAdminNet] AS [dbo]
GO
