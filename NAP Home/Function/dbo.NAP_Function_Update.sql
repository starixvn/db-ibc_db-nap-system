USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Function_Update]    Script Date: 8/1/2014 1:34:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Function_Update]
    @FunctionId			INT,	
	@SiteId				INT,									
	@FunctionName		NVARCHAR(50),	
	@FunctionKey		NVARCHAR(50),	
	@Description		NVARCHAR(200)	= NULL,	
	@ParentId			INT				= NULL,	
	@ParentName			NVARCHAR(50)	= NULL,	
    @CRUD				TINYINT,
	@DisplayOrder		INT,
	@IsActive			BIT,
    @ModifiedBy			INT				= NULL, 
    @ModifiedDate		DATETIME,
	@Environment		VARCHAR(10)		= 'UAT',				-- 'UAT', 'LIVE'
    @CurrentUserId		INT,
    @CurrentSiteId		INT,
	@LogDate			DATETIME,
	@LoginIP			VARCHAR(30)		= '',
	@Language			VARCHAR(20)		= 'en-us',
	@ErrCode			INT				= 0			OUTPUT, 
	@ErrMsg				NVARCHAR(1000)	= ''		OUTPUT 
AS

/*  
 * Created: 20120810@Kos
 * Task : Update function information
 * DB: bodb_NAP
 *  
 * Revisions:     
	-20120821@Edward Add function update all table contains FunctionId when SiteId change
	-29112012@Edward update write log	
 * Param's Explanation: 
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

	-- write log before update
	SET @xml = (
		SELECT f.FunctionId			AS '@fi'
				,f.FunctionName		AS '@f'	
				,s.SiteId			AS '@si'
				,s.SiteName			AS '@s'
				,f.FunctionKey		AS '@fk'
				,f.Description		AS '@d'
				,f.ParentId			AS '@pi'
				,f.ParentName		AS '@p'
				,f.CRUD				AS '@c'
				,f.DisplayOrder		AS '@o'
				,f.IsActive			AS '@i'
				,f.Environment		AS '@e'				
		FROM Functions AS f WITH (NOLOCK)
		INNER JOIN Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		WHERE f.FunctionId =  @FunctionId
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')

	-- SiteId and EnvironmentId before update
	DECLARE @OldSiteId INT
	DECLARE @OldEnvironment VARCHAR(10)
	DECLARE @OldCRUD	TINYINT

	SELECT 
		@OldSiteId		= SiteId,
		@OldEnvironment = Environment,
		@OldCRUD		= CRUD
	FROM dbo.Functions 
	WHERE FunctionId = @FunctionId

	-- Update function information
	UPDATE dbo.Functions 
	SET	
		SiteId			= @SiteId,
		FunctionName	= @FunctionName,
		FunctionKey		= @FunctionKey,
		Description		= @Description,
		ParentId		= @ParentId,
		ParentName		= @ParentName,
		CRUD			= @CRUD,
		DisplayOrder	= @DisplayOrder,
		IsActive		= @IsActive,
		ModifiedBy		= @ModifiedBy,
		ModifiedDate	= @ModifiedDate,
		Environment		= @Environment
	WHERE FunctionId	= @FunctionId

	-- Update all table contains FunctionId = @FunctionID
	-- and SiteId change
	IF (@OldSiteId != @SiteId)
		BEGIN
			UPDATE dbo.MenuItems
			SET SiteId = @SiteId
			WHERE FunctionId = @FunctionId

			UPDATE dbo.GroupFunction
			SET SiteId = @SiteId
			WHERE FunctionId = @FunctionId

			UPDATE dbo.UserFunction
			SET SiteId = @SiteId
			WHERE FunctionId = @FunctionId
		END
	
	-- update permission (from readonly to non readonly) for site admin and portal admin
	IF (@CRUD > @OldCRUD)
		BEGIN
			UPDATE UserFunction 
			SET Policy = 2
			WHERE UserId IN (
				SELECT DISTINCT us.UserId 
				FROM UserSite AS us WITH(NOLOCK) 
				WHERE us.Level IN(50,100) 
			)			
			AND FunctionId = @FunctionId		
		END
	--update permission (from non read only to readonly) for all user has permission in this function
	IF (@CRUD < @OldCRUD)
		BEGIN
			UPDATE UserFunction 
			SET Policy = 1
			WHERE UserId IN (
				SELECT DISTINCT uf.UserId
				FROM UserFunction AS uf WITH (NOLOCK)
				WHERE uf.FunctionId = @FunctionId
				AND uf.Policy = 2
			)
			AND FunctionId = @FunctionId					
		END		

	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Fail to update information of the FunctionId ' + CONVERT(VARCHAR(10), @FunctionId)
			RETURN
		END		
	ELSE
		BEGIN
			-- Check if Environment change, will be update for all function childs
			IF @OldEnvironment != @Environment
				BEGIN
					-- Get list function child of FunctionId
					;WITH FunctionChild AS (
						SELECT  FunctionId 
						FROM    Functions WITH (NOLOCK)
						WHERE   FunctionId = @FunctionId

						UNION ALL

						SELECT  f.FunctionId 
						FROM    
							Functions AS f WITH(NOLOCK) 
							INNER JOIN FunctionChild r ON f.ParentId = r.FunctionId
					)
					
					-- Update Environment for all function child
					UPDATE dbo.Functions 
					SET	Environment = @Environment
					WHERE FunctionId IN ( SELECT  FunctionId FROM FunctionChild)
				END
		END

	-- Write log after update
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
	@SPName			= 'NAP_Function_Update',
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
GRANT EXECUTE ON [dbo].[NAP_Function_Update] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_Update] TO [vnteam] AS [dbo]