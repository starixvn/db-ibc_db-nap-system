 ALTER PROCEDURE [dbo].[NAP_MenuItem_Update]
    @MenuItemId			INT,	
	@FunctionId			INT,	
	@SiteId				INT,	
	@MenuItemName		NVARCHAR(50),	
	@Description		NVARCHAR(200)		= NULL,	
	@ParentId			INT					= NULL,	
	@ParentName			NVARCHAR(50)		= NULL,	
    @Policy				TINYINT,
	@URL				NVARCHAR(200)		= NULL,	
	@DisplayOrder		INT,
	@IsActive			BIT,
    @ModifierId			INT					= NULL, 
    @ModifiedDate		DATETIME,
	@Environment		VARCHAR(10)			= 'UAT',				-- 'UAT', 'LIVE'
    @CurrentUserId		INT,     
    @CurrentSiteId		INT	,
	@LogDate			DATETIME,
	@LoginIP			VARCHAR(30)			= '',
	@Language			VARCHAR(20)			= 'en-us',
	@ErrCode			INT					= 0			OUTPUT, 
	@ErrMsg				NVARCHAR(1000)		= ''		OUTPUT 
AS

/*  
 * Created	: 20120810@Kos
 * Task		: Update menu item information
 * DB		: bodb_NAP
 *  
 * Revisions:     
	- 20120830@Edward : Update Environment of child when parent change
 * Param's Explanation: 	
	• Main	:	
				<root><xml path="r" />
					<row item="MenuItemId" alias="mi" />
					<row item="MenuItemName" alias="m" />	
					<row item="FunctionId" alias="fi" />					
					<row item="FunctionName" alias="f" />					
					<row item="SiteId" alias="si" />					
					<row item="SiteName" alias="s" />									
					<row item="Description" alias="d" />					
					<row item="ParentId" alias="pi" />					
					<row item="ParentName" alias="p" />					
					<row item="Policy" alias="pl" />					
					<row item="URL" alias="u" />					
					<row item="DisplayOrder" alias="o" />					
					<row item="IsActive" alias="i" />					
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
		SELECT @MenuItemId			AS '@mi'
				,m.MenuItemName		AS '@m'
				,m.FunctionId		AS '@fi'
				,f.FunctionName		AS '@f'
				,m.SiteId			AS '@si'
				,s.SiteName			AS '@s'
				,m.Description		AS '@d'
				,m.ParentId			AS '@pi'
				,m.ParentName		AS '@p'
				,m.Policy			AS '@pl'
				,m.URL				AS '@u'
				,m.DisplayOrder		AS '@o'
				,m.IsActive			AS '@i'
		FROM MenuItems AS m WITH (NOLOCK)
		INNER JOIN Functions AS f WITH (NOLOCK) ON m.FunctionId = f.FunctionId
		INNER JOIN Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		WHERE m.MenuItemId = @MenuItemId
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')		
	
	-- Get Environment before update
	DECLARE @EnvironmentOld VARCHAR(10)

	SELECT @EnvironmentOld = Environment
	FROM MenuItems
	WHERE MenuItemId = @MenuItemId

	-- Update menu item information
	UPDATE dbo.MenuItems 
	SET	
		FunctionId		= @FunctionId,
		SiteId			= @SiteId,
		MenuItemName	= @MenuItemName,
		Description		= @Description,
		ParentId		= @ParentId,
		ParentName		= @ParentName,
		Policy			= @Policy,
		URL				= @URL,
		DisplayOrder	= @DisplayOrder,
		IsActive		= @IsActive,
		ModifiedBy		= @ModifierId,
		ModifiedDate	= @ModifiedDate,
		Environment		= @Environment
	WHERE MenuItemId	= @MenuItemId

	-- Check error
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Fail to update information of the MenuItemId ' + CONVERT(VARCHAR(10), @MenuItemId)
			RETURN
		END		
	ELSE
		BEGIN
			-- Check if Environment is change will be update all menu item child
			IF (@EnvironmentOld != @Environment)
				BEGIN
					-- Get list menu item is child of this menuId
					;WITH MenuItemChild AS(
						SELECT  MenuItemId 
						FROM    MenuItems WITH (NOLOCK)
						WHERE   MenuItemId = @MenuItemId
						UNION ALL
						SELECT  t.MenuItemId 
						FROM    
							MenuItems AS t WITH(NOLOCK) 
							INNER JOIN MenuItemChild r ON t.ParentId = r.MenuItemId
					)
					
					-- Update Environment of all menu item child
					UPDATE dbo.MenuItems 
					SET	Environment = @Environment
					WHERE MenuItemId IN ( SELECT  MenuItemId FROM    MenuItemChild)
				END
		END

	-- Write log after update
	SET @xml = (
		SELECT @MenuItemId			AS '@mi'
				,@MenuItemName		AS '@m'
				,@FunctionId		AS '@fi'
				,f.FunctionName		AS '@f'
				,@SiteId			AS '@si'
				,s.SiteName			AS '@s'
				,@Description		AS '@d'
				,@ParentId			AS '@pi'
				,@ParentName		AS '@p'
				,@Policy			AS '@pl'
				,@URL				AS '@u'
				,@DisplayOrder		AS '@o'
				,@IsActive			AS '@i'
		FROM MenuItems AS m WITH (NOLOCK)
		INNER JOIN Functions AS f WITH (NOLOCK) ON m.FunctionId = f.FunctionId
		INNER JOIN Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		WHERE m.MenuItemId = @MenuItemId
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')		
		
	SET @endRun		= GETDATE()  
	SET @duration	= DATEDIFF(millisecond, @startRun, @endRun)   

	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_MenuItem_Update',
	@ObjectId		= @MenuItemId,
	@ObjectTypeId	= 5,			--Object type : menu item
	@Language		= @Language,
	@SiteID			= @CurrentSiteId,
	@IP				= @LoginIP,
	@Date			= @LogDate,
	@Data			= @logSPData,
	@OldData		= @logSPDataOld,
	@Duration		= @Duration

END



GO
GRANT EXECUTE ON [dbo].[NAP_MenuItem_Update] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_MenuItem_Update] TO [vnteam] AS [dbo]