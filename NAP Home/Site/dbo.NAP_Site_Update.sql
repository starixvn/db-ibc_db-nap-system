 ALTER PROCEDURE [dbo].[NAP_Site_Update]
    @SiteId			INT
	,@SiteName		VARCHAR(50)
	,@Description	VARCHAR(200)		= NULL
    ,@URL			VARCHAR(200)		= NULL
	,@TestURL		VARCHAR(200)		= NULL
    ,@IsActive		BIT
    ,@Environment	VARCHAR(10)									--Values : UAT,LIVE
	,@CurrentUserId	INT     
    ,@CurrentSiteId INT	
	,@LogDate		DATETIME
	,@LoginIP		VARCHAR(30)			= ''
	,@Language		VARCHAR(20)			= 'en-us'
	,@ErrCode		INT					= 0			OUTPUT 
	,@ErrMsg		NVARCHAR(1000)		= ''		OUTPUT 
AS
/*  
 * Created	: 20120809@Edward
 * Task		: Update information of site
 * DB		: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
	*** WRITE LOG template:
	Main: 		<root><xml path="r" />			<row item="SiteId" alias="si" />			<row item="SiteName" alias="s" />			<row item="Description" alias="d" />			<row item="IsActive" alias="i" />			<row item="Environment" alias="e" />		</root>
*/
BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE @startRun	DATETIME  
		,@endRun		DATETIME  
		,@duration		INT
		,@logSPData		VARCHAR(5000)
		,@logSPDataOld	VARCHAR(5000)
		,@xml			XML

	SET @startRun = GETDATE()	
	-- write log before update
	SET @xml = (
		SELECT @SiteId			AS '@si'	
				,s.SiteName		AS '@s'
				,s.Description	AS '@d'
				,s.Environment	AS '@e'	
				,s.IsActive		AS '@i'
		FROM Sites AS s WITH(NOLOCK)
		WHERE s.SiteId = @SiteId				
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	-- Update site information
	UPDATE dbo.Sites 
	SET SiteName = @SiteName
        ,Description = @Description
        ,Environment = @Environment
        ,IsActive = @IsActive
        ,URL = @URL
		,TestURL = @TestURL
    WHERE SiteId = @SiteId
	
	-- Check error
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Fail to insert information of the SiteId ' + CONVERT(VARCHAR(10), @SiteId)
			RETURN
		END		

	--write log after update
	SET @xml = (
		SELECT @SiteId			AS '@si'	
				,@SiteName		AS '@s'
				,@Description	AS '@d'
				,@Environment	AS '@e'	
				,@IsActive		AS '@i'				
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Site_Update',
	@ObjectId		= @SiteId,
	@ObjectTypeId	= 3,			--Object type : Site
	@Language		= @Language,
	@SiteID			= @CurrentSiteId,
	@IP				= @LoginIP,
	@Date			= @LogDate,
	@Data			= @logSPData,
	@OldData		= @logSPDataOld,
	@Duration		= @Duration

END



GO
GRANT EXECUTE ON [dbo].[NAP_Site_Update] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_Update] TO [vnteam] AS [dbo]