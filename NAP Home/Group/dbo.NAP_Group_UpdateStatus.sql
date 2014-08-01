USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Group_UpdateStatus]    Script Date: 8/1/2014 1:38:29 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Group_UpdateStatus]
    @GroupId			INT	
    ,@IsActive			BIT
    ,@ModifiedBy		INT 
    ,@ModifiedDate		DATETIME
	,@CurrentUserId		INT
    ,@CurrentSiteId		INT
	,@LoginIP			VARCHAR(30)		=	''
	,@LogDate			DATETIME
	,@Language			VARCHAR(20)		=	'en-us'	
	,@ErrCode			INT				=	0			OUTPUT 
	,@ErrMsg			NVARCHAR(1000)	=	''			OUTPUT 
AS
/*  
 * Created	: 20120810@Edward
 * Task		: Update status of group
 * DB		: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
	• Main	:	<root><xml path="r" />
					<row item="GroupId" alias="gi" />					
					<row item="IsActive" alias="i" />					
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
				
	SET @startRun = GETDATE()	

	-- Get log data
	SET @xml = (
		SELECT @GroupId				AS '@gi'			
				,g.IsActive			AS '@i'
		FROM Groups AS g WITH (NOLOCK)
		WHERE g.GroupId = @GroupId	
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	-- Update status of group
	UPDATE dbo.Groups 
	SET  IsActive		= @IsActive        
		,ModifiedBy		= @ModifiedBy
		,ModifiedDate	= @ModifiedDate
    WHERE GroupId = @GroupId
	
	-- Check error
	IF @@ERROR>0
		BEGIN
			SELECT 
				@ErrCode	= 1, 
				@ErrMsg		= 'Fail to update status of the GroupId ' + CONVERT(VARCHAR(10), @GroupId)
			RETURN
		END		

	-- Write log
	SET @xml = (
		SELECT @GroupId				AS '@gi'				
				,@IsActive			AS '@i'
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')		
		
	SET @endRun		= GETDATE()  
	SET @duration	= DATEDIFF(millisecond, @startRun, @endRun)   

	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Group_UpdateStatus',
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
GRANT EXECUTE ON [dbo].[NAP_Group_UpdateStatus] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Group_UpdateStatus] TO [vnteam] AS [dbo]