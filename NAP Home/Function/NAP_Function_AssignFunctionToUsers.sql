/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_Function_AssignFunctionToUsers]
	@FunctionId		INT,
	@SiteId			INT,
	@Value			NVARCHAR(MAX),
	@ModifiedBy		INT,
	@ModifiedDate	DATETIME,
	@CurrentUserId	INT,
	@CurrentSiteId	INT,
	@LogDate		DATETIME,
	@LoginIP		VARCHAR(30)		= '',
	@Language		VARCHAR(20)		= 'en-us',
	@ErrCode		INT				= 0		OUTPUT,
	@ErrMsg			NVARCHAR(1000)	= ''	OUTPUT
AS

/*
	Created: 20121101@Lewis
	Task: Assign function to users
	DB: DBPOL/NAP_UserControl

	Revisions:
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust [Redmine:100493]
		- 20220615@Kos: Handle SELECT INTO using temp table [RedmineID: #174035]

	Param's Explanation: 
			- Value : '<ROOT><FunctionPolicy UserId='{0}' Policy='{1}'></FunctionPolicy></ROOT>'
*/

BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		VARCHAR(5000)
		,@logSPDataOld	VARCHAR(5000)
		,@xml			XML

	SET @startRun = GETDATE()

	CREATE TABLE #TempData (
		FunctionId	SMALLINT,
		Policy		TINYINT,
		UserId		INT,
		Username	VARCHAR(30)
	)

	-- Write log before update
	INSERT INTO #TempData (FunctionId, Policy, UserId, Username)
	SELECT
		uf.FunctionId,
		uf.Policy,
		uf.UserId,
		cu.username 
	FROM dbo.NAP_UserFunction AS uf WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer AS cu WITH(NOLOCK) ON uf.UserId = cu.custid
	WHERE uf.FunctionId = @FunctionId

	SET @xml = (
		SELECT @FunctionId				AS '@f'
				,(
					SELECT uf.UserId	AS '@ui'
						,uf.Policy		AS '@p'
						,uf.username	AS '@u'
					FROM  #TempData		AS uf
					FOR XML PATH('z'), TYPE
				)
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld	= REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')

	-- Read information from @Value and insert into temp table
	DECLARE @TblFuncPolicy TABLE (UserId INT, Policy INT)

	DECLARE @DocHandler INT

	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @Value

	INSERT INTO @TblFuncPolicy (UserId, Policy)
	SELECT Data.UserId, Data.Policy
	FROM OPENXML (@DocHandler, '/ROOT/FunctionPolicy', 1)
	WITH (UserId INT, Policy INT) AS Data

	EXEC sp_xml_removedocument @DocHandler

	--Update policy for users assigned the function already
	UPDATE dbo.NAP_UserFunction
	SET
		Policy			= 1
		,ModifiedBy		= @ModifiedBy
		,ModifiedDate	= @ModifiedDate
	WHERE
		FunctionId = @FunctionId
		AND SiteId = @SiteId
		AND UserId IN (SELECT UserId FROM @TblFuncPolicy WHERE Policy = 1)

	UPDATE dbo.NAP_UserFunction
	SET
		Policy			= 2
		,ModifiedBy		= @ModifiedBy
		,ModifiedDate	= @ModifiedDate
	WHERE
		FunctionId = @FunctionId
		AND SiteId = @SiteId
		AND UserId IN (SELECT UserId FROM @TblFuncPolicy WHERE Policy = 2)

	-- Assigns the fucntion to new users
	INSERT INTO dbo.NAP_UserFunction (
		UserId
		,FunctionId
		,SiteId
		,Policy
		,CreatedBy
		,CreatedDate
		,ModifiedBy
		,ModifiedDate
	)
	SELECT
		Temp.UserId
		,@FunctionId
		,@SiteId
		,Temp.Policy
		,@ModifiedBy
		,@ModifiedDate
		,@ModifiedBy
		,@ModifiedDate
	FROM @TblFuncPolicy AS Temp
	WHERE NOT EXISTS (	SELECT TOP(1) *
						FROM dbo.NAP_UserFunction AS uf WITH (NOLOCK)
						WHERE uf.UserId = Temp.UserId AND uf.FunctionId = @FunctionId )

	IF @@ERROR > 0
	BEGIN
		SELECT
			@ErrCode = 1,
			@ErrMsg = 'Failed to assign function to users [FunctionId=' + COALESCE(CAST(@FunctionId AS VARCHAR(10)), SPACE(1)) + ']'
		RETURN
	END

	-- write log after update
	SET @xml = (
		SELECT @FunctionId		AS '@f'
				,(					
					SELECT uf.UserId		AS '@ui'
							,uf.Policy		AS '@p'
							,cu.username		AS '@u'
					FROM dbo.NAP_UserFunction AS uf WITH (NOLOCK)
						LEFT JOIN #TempData AS t ON uf.UserId = t.UserId AND uf.Policy = t.Policy
						INNER JOIN CUSTDB.dbo.Customer AS cu WITH(NOLOCK) ON uf.UserId = cu.custid
					WHERE uf.FunctionId = @FunctionId AND t.UserId IS NULL
					FOR XML PATH('z'), TYPE
				)
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.NAP_RunSP_WriteLog
		@UserId			= @CurrentUserId,
		@SPName			= 'NAP_Function_AssignFunctionToUsers',
		@ObjectId		= @FunctionId,
		@ObjectTypeId	= 4,			--Object type : Function
		@Language		= @Language,
		@SiteID			= @CurrentSiteId,
		@IP				= @LoginIP,
		@Date			= @LogDate,
		@Data			= @logSPData,
		@OldData		= @logSPDataOld,
		@Duration		= @Duration

	DROP TABLE #TempData
END
GO
