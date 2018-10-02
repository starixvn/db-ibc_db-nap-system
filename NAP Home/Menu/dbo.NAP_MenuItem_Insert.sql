/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_MenuItem_Insert]
    @MenuItemId			INT							OUTPUT,	
	@FunctionId			INT,	
	@SiteId				INT,	
	@MenuItemName		NVARCHAR(50),	
	@Description		NVARCHAR(200)	= NULL,	
	@ParentId			INT				= NULL,	
	@ParentName			NVARCHAR(50)	= NULL,	
    @Policy				TINYINT,
	@URL				NVARCHAR(200)	= NULL,	
	@DisplayOrder		INT,
	@IsActive			BIT,
    @CreatedBy			INT				= NULL, 
    @CreatedDate		DATETIME,
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
 * Created	: 20120810@Kos
 * Task		: Add a new menu item
 * DB		: bodb_NAP
 *  
 * Revisions:    
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	
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

	-- Insert new menu item
	INSERT INTO dbo.NAP_MenuItems 
	(
		FunctionId,
		SiteId,
		MenuItemName,
		Description,
		ParentId,
		ParentName,
		Policy,
		URL,
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
		@FunctionId,
		@SiteId,
		@MenuItemName,
		@Description,
		@ParentId,
		@ParentName,
		@Policy,
		@URL,
		@DisplayOrder,
		@IsActive,
		@CreatedBy,
		@CreatedDate,
		@CreatedBy,
		@CreatedDate,
		@Environment
	)
		
	-- Get menu item id current insert
	SET @MenuItemId = SCOPE_IDENTITY()

	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Fail to insert information of the MenuItemId ' + CONVERT(VARCHAR(10), @MenuItemId)
			RETURN
		END		

	-- Write log
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
		FROM dbo.NAP_MenuItems AS m WITH (NOLOCK)
		INNER JOIN dbo.NAP_Functions AS f WITH (NOLOCK) ON m.FunctionId = f.FunctionId
		INNER JOIN dbo.NAP_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		WHERE m.MenuItemId = @MenuItemId
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')		
		
	SET @endRun		= GETDATE()  
	SET @duration	= DATEDIFF(millisecond, @startRun, @endRun)   

	EXEC dbo.NAP_RunSP_WriteLog
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_MenuItem_Insert',
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
GRANT EXECUTE ON [dbo].[NAP_MenuItem_Insert] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_MenuItem_Insert] TO [vnteam] AS [dbo]