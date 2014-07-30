 ALTER PROCEDURE [dbo].[NAP_Group_Update]
	@GroupId			INT
	,@GroupName			VARCHAR(50)
	,@Description		VARCHAR(200)    = NULL
    ,@IsActive			BIT    
	,@ModifiedBy		INT
    ,@ModifiedDate		DATETIME
    ,@CurrentUserId		INT
    ,@CurrentSiteId		INT
	,@LogDate			DATETIME
	,@LoginIP			VARCHAR(30)		= ''
	,@Language			VARCHAR(20)		= 'en-us'	
	,@ErrCode			INT				= 0			OUTPUT 
	,@ErrMsg			NVARCHAR(1000)	= ''		OUTPUT 
AS

/*  
 * Created	: 20120810@Edward
 * Task		: Update information of group
 * DB		: bodb_NAP
 *  
 * Revisions:     

 * Param's Explanation: 
	• Main	:	<root><xml path="r" />
					<row item="GroupId" alias="gi" />
					<row item="GroupName" alias="g" />					
					<row item="Description" alias="d" />					
					<row item="IsActive" alias="i" />					
				</root>
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun	DATETIME  
		,@endRun		DATETIME  
		,@duration		INT
		,@logSPData		VARCHAR(5000)
		,@logSPDataOld	VARCHAR(5000)		
		,@xml			XML

	SET @startRun = GETDATE()	

	-- Get log data before update
	SET @xml = (
		SELECT @GroupId				AS '@gi'
				,g.GroupName		AS '@g'
				,g.Description		AS '@d'				
				,g.IsActive			AS '@i'
		FROM Groups AS g WITH (NOLOCK)
		WHERE g.GroupId = @GroupId	
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	-- Update group information
	UPDATE dbo.Groups
    SET GroupName		= @GroupName
        ,Description	= @Description
        ,IsActive		= @IsActive
        ,ModifiedBy		= @ModifiedBy
        ,ModifiedDate	= @ModifiedDate
    WHERE GroupId = @GroupId	
	
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode	= 1, 
				@ErrMsg		= 'Fail to update group of the GroupId ' + CONVERT(VARCHAR(10), @GroupId)
			RETURN
		END		

	-- Write log
	SET @xml = (
		SELECT @GroupId				AS '@gi'
				,@GroupName			AS '@g'
				,@Description		AS '@d'				
				,@IsActive			AS '@i'
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')		
		
	SET @endRun		= GETDATE()  
	SET @duration	= DATEDIFF(millisecond, @startRun, @endRun)   

	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Group_Update',
	@ObjectId		= @GroupId,
	@ObjectTypeId	= 2,					-- Object type : Group
	@Language		= @Language,
	@SiteID			= @CurrentSiteId,
	@IP				= @LoginIP,
	@Date			= @LogDate,
	@Data			= @logSPData,
	@OldData		= @logSPDataOld,
	@Duration		= @Duration
END



GO
GRANT EXECUTE ON [dbo].[NAP_Group_Update] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Group_Update] TO [vnteam] AS [dbo]