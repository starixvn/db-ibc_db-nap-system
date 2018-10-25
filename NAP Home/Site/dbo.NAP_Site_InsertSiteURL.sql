/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Site_InsertSiteURL]
	@SiteUrlId		INT								OUTPUT
	,@SiteId		INT
    ,@URL			VARCHAR(100)
	,@Environment	VARCHAR(10)	-- Values: UAT | LIVE    
	,@IsActive		BIT
	,@IsDefault		BIT    
	,@CurrentUserId	INT     
    ,@CurrentSiteId INT	
	,@LogDate		DATETIME
	,@LoginIP		VARCHAR(30)			= ''
	,@Language		VARCHAR(20)			= 'en-us'
	,@ErrCode		INT					= 0			OUTPUT 
	,@ErrMsg		NVARCHAR(1000)		= ''		OUTPUT 
AS
/*  
 * Created: 20121011@Lewis
 * Task: Add a new site url
 * DB: DBPOL-NAP_UserControl
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	     
 * Param's Explanation:
	*** WRITE LOG template:
	Main: 
		<root><xml path="r" /><row item="SiteId" alias="s" /></root>
	Sub: 
		<root><xml path="r/z" />
				<row item="SiteURLId" alias="si" />				
				<row item="URL" alias="u" />
				<row item="Environment" alias="e" />
				<row item="IsDefault" alias="id" />
				<row item="IsActive" alias="ia" />
		</root>
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

	SET @startRun = getdate()

	-- Get log data
	SET @xml = (
		SELECT @SiteId as '@s'				
				,(
					SELECT 	su.SiteURLId	AS '@si'
							,su.URL			AS '@u'	
							,su.Environment	AS '@e'
							,su.IsDefault	AS '@id'
							,su.IsActive	AS '@ia'
					FROM dbo.NAP_SiteURL AS su WITH (NOLOCK)
					WHERE SiteId = @SiteId
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')

	-- Add new site url
	INSERT dbo.NAP_SiteURL (
		SiteId, 
		URL, 
		Environment, 
		IsActive, 
		IsDefault)
	VALUES
		(@SiteId, @URL, @Environment, @IsActive, @IsDefault)

	SET @SiteUrlId = SCOPE_IDENTITY()

	-- Check error
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Failed to insert site url [SiteId = ' + COALESCE(CAST(@SiteId AS VARCHAR(10)), '') + ']'
			RETURN
		END

	-- for write log
	SET @xml = (
		SELECT @SiteId as '@s'				
				,(
					SELECT 	su.SiteURLId	AS '@si'
							,su.URL			AS '@u'	
							,su.Environment	AS '@e'
							,su.IsDefault	AS '@id'
							,su.IsActive	AS '@ia'
					FROM dbo.NAP_SiteURL AS su WITH (NOLOCK)
					WHERE SiteId = @SiteId
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC dbo.NAP_RunSP_WriteLog 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Site_InsertSiteURL',
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
GRANT EXECUTE ON [dbo].[NAP_Site_InsertSiteURL] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_InsertSiteURL] TO [vnteam] AS [dbo]