 ALTER PROCEDURE [dbo].[NAP_Site_UpdateStatus]
    @SiteId			INT	
    ,@IsActive		BIT
    ,@CurrentUserId	INT     
    ,@CurrentSiteId INT	
	,@LogDate		DATETIME
	,@LoginIP		VARCHAR(30)			= ''
	,@Language		VARCHAR(20)			= 'en-us'
	,@ErrCode		INT					= 0			OUTPUT 
	,@ErrMsg		NVARCHAR(1000)		= ''		OUTPUT 
AS
/*  
 * Created	: 20120810@Edward
 * Task		: Update status of site
 * DB		: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
		Main: 		<root><xml path="r" /><row item="SiteId" alias="s" /><row item="IsActive" alias="i" /></root>
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
		SELECT @SiteId			AS '@s'
				,s.IsActive 	AS '@i'			
		FROM Sites AS s WITH(NOLOCK)
		WHERE s.SiteId = @SiteId				
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	-- Update site information
	UPDATE dbo.Sites 
	SET IsActive = @IsActive        
    WHERE SiteId = @SiteId
	
	-- Check error
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Fail to update status of the SiteId ' + CONVERT(VARCHAR(10), @SiteId)
			RETURN
		END		
	
	--write log after update
	SET @xml = (
		SELECT @SiteId		AS '@s'				
				,@IsActive	AS '@i'
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Site_UpdateStatus',
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
GRANT EXECUTE ON [dbo].[NAP_Site_UpdateStatus] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_UpdateStatus] TO [vnteam] AS [dbo]