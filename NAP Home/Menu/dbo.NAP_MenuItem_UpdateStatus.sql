 ALTER PROCEDURE [dbo].[NAP_MenuItem_UpdateStatus]
    @MenuItemId			INT,	
    @IsActive			BIT,
    @ModifiedBy			INT, 
	@ModifiedDate		DATETIME,
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
 * Task		: Update status of menu item
 * DB		: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
	• Main	:	
				<root><xml path="r" />
					<row item="MenuItemId" alias="mi" />					
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

	-- Write log before update
	SET @xml = (
		SELECT @MenuItemId			AS '@mi'				
				,m.IsActive			AS '@i'
		FROM MenuItems AS m WITH (NOLOCK)		
		WHERE m.MenuItemId = @MenuItemId
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	-- Update menu item information
	UPDATE dbo.MenuItems 
	SET	
		IsActive		= @IsActive,
		ModifiedBy		= @ModifiedBy,
		ModifiedDate	= @ModifiedDate
	WHERE MenuItemId = @MenuItemId

	-- Check error
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode	= 1, 
				@ErrMsg		= 'Fail to update status of the MenuItemId ' + CONVERT(VARCHAR(10), @MenuItemId)
			RETURN
		END		

	-- Write log after update
	SET @xml = (
		SELECT @MenuItemId			AS '@mi'				
				,@IsActive			AS '@i'		
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')		
		
	SET @endRun		= GETDATE()  
	SET @duration	= DATEDIFF(millisecond, @startRun, @endRun)   

	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_MenuItem_UpdateStatus',
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
GRANT EXECUTE ON [dbo].[NAP_MenuItem_UpdateStatus] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_MenuItem_UpdateStatus] TO [vnteam] AS [dbo]