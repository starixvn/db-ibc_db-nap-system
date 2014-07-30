 ALTER PROCEDURE [dbo].[NAP_Function_Insert]
    @FunctionId			INT							OUTPUT,	
	@SiteId				INT,	
	@FunctionName		NVARCHAR(50),	
	@FunctionKey		NVARCHAR(50),	
	@Description		NVARCHAR(200)	= NULL,	
	@ParentId			INT				= NULL,	
	@ParentName			NVARCHAR(50)	= NULL,	
    @CRUD				TINYINT,
	@DisplayOrder		INT,
	@IsActive			BIT,	
    @CreatedBy			INT				= NULL, 
    @CreatedDate		DATETIME,
	@Environment		VARCHAR(10)		= 'UAT',	-- 'UAT', 'LIVE'
    @CurrentUserId		INT,
    @CurrentSiteId		INT,
	@LogDate			DATETIME,
	@LoginIP			VARCHAR(30)		= '',
	@Language			VARCHAR(20)		= 'en-us',
	@ErrCode			INT				= 0			OUTPUT, 
	@ErrMsg				NVARCHAR(1000)	= ''		OUTPUT 
AS

/*  
 * Created	: 20120810@Kos
 * Task		: Add a new function
 * DB		: bodb_NAP
 *  
 * Revisions:
 * Param's Explanation:	
	@CRUD :
		= 0 : Is read only permission
		= 1 : Host permission

	• Main	:	<root><xml path="r" />
					<row item="FunctionId" alias="fi" />
					<row item="FunctionName" alias="f" />
					<row item="SiteId" alias="si" />
					<row item="SiteName" alias="s" />
					<row item="FunctionKey" alias="fk" />
					<row item="Description" alias="d" />
					<row item="ParentId" alias="pi" />
					<row item="ParentName" alias="p" />
					<row item="CRUD" alias="c" />
					<row item="DisplayOrder" alias="o" />
					<row item="IsActive" alias="i" />
					<row item="Environment" alias="e" />
				</root>
*/

BEGIN

	SET NOCOUNT ON

	-- For write log
	DECLARE 
		@startRun		DATETIME,
		@endRun			DATETIME,
		@duration		INT,
		@logSPData		VARCHAR(5000),
		@logSPDataOld	VARCHAR(5000),	
		@xml			XML

	SET @startRun = GETDATE()	

	-- Inserts function
	INSERT dbo.Functions 
	(
		SiteId,
		FunctionName,
		FunctionKey,
		Description,
		ParentId,
		ParentName,
		CRUD,
		DisplayOrder,
		IsActive,
		CreatedBy,
		CreatedDate,
		ModifiedBy,
		ModifiedDate,
		Environment    
	)
	VALUES
	(
		@SiteId,
		@FunctionName,
		@FunctionKey,
		@Description,
		@ParentId,
		@ParentName,
		@CRUD,
		@DisplayOrder,
		@IsActive,
		@CreatedBy,
		@CreatedDate,
		@CreatedBy,
		@CreatedDate,
		@Environment    
	)
	
	-- Get functionId, current insert
	SET @FunctionId = SCOPE_IDENTITY()

	DECLARE @policy TINYINT

	IF @CRUD = 0
		SET @policy = 1 -- read policy
	ELSE
		SET @policy = 2 -- host policy

	-- assigns the new function to all site admins of @SiteId and all portal admins
	INSERT dbo.UserFunction
	(
		UserId,
		FunctionId,
		SiteId,
		Policy,
		CreatedDate,
		ModifiedDate
	)
	SELECT
		us.UserId,
		@FunctionId,
		@SiteId,
		@policy,
		@startRun,
		@startRun
	FROM
		dbo.UserSite us
	WHERE
		us.SiteId = @SiteId 
	AND us.[Level] IN (50, 100) -- Site admin: 50, Portal admin: 100

	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Failed to insert function [FunctionId = ' + COALESCE(CAST(@FunctionId AS VARCHAR(10)), SPACE(1)) + ']'
			RETURN
		END		

	-- Write log after insert
	SET @xml = (
		SELECT @FunctionId			AS '@fi'
				,@FunctionName		AS '@f'	
				,@SiteId			AS '@si'
				,s.SiteName			AS '@s'
				,@FunctionKey		AS '@fk'
				,@Description		AS '@d'
				,@ParentId			AS '@pi'
				,@ParentName		AS '@p'
				,@CRUD				AS '@c'
				,@DisplayOrder		AS '@o'
				,@IsActive			AS '@i'
				,@Environment		AS '@e'				
		FROM Sites AS s WITH (NOLOCK)
		WHERE s.SiteId = @SiteId
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')		
		
	SET @endRun		= GETDATE()  
	SET @duration	= DATEDIFF(millisecond, @startRun, @endRun)   

	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Function_Insert',
	@ObjectId		= @FunctionId,
	@ObjectTypeId	= 4,					-- Object type : Function
	@Language		= @Language,
	@SiteID			= @CurrentSiteId,
	@IP				= @LoginIP,
	@Date			= @LogDate,
	@Data			= @logSPData,
	@OldData		= @logSPDataOld,
	@Duration		= @Duration
END



GO
GRANT EXECUTE ON [dbo].[NAP_Function_Insert] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_Insert] TO [vnteam] AS [dbo]