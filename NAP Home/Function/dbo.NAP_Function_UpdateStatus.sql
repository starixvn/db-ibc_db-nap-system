/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Function_UpdateStatus]
    @FunctionId			INT,	
    @IsActive			BIT,
    @ModifiedBy			INT, 
    @ModifiedDate		DATETIME,
    @CurrentUserId		INT,
    @CurrentSiteId		INT,
	@LogDate			DATETIME,
	@LoginIP			VARCHAR(30)		=	'',
	@Language			VARCHAR(20)		=	'en-us',
	@ErrCode			INT				=	0			OUTPUT, 
	@ErrMsg				NVARCHAR(1000)	=	''			OUTPUT 
AS
/*  
	Created	: 20120810@Kos
	Task	: Update status of function
	DB		: DBPOL-NAP_UserControl

	Revisions: 
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]    
	Param's Explanation: 
	• Main	:	<root><xml path="r" />
					<row item="FunctionId" alias="fi" />					
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
		SELECT @FunctionId			AS '@fi'				
				,f.IsActive			AS '@i'							
		FROM dbo.NAP_Functions AS f WITH (NOLOCK)		
		WHERE f.FunctionId =  @FunctionId
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')

	-- Update status of function
	UPDATE dbo.NAP_Functions 
	SET	IsActive		= @IsActive,
		ModifiedBy		= @ModifiedBy,
		ModifiedDate	= @ModifiedDate
	WHERE FunctionId	= @FunctionId

	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode	= 1, 
				@ErrMsg		= 'Fail to update status of the FunctionId ' + CONVERT(VARCHAR(10), @FunctionId)
			RETURN
		END		

	-- Write log after update
	SET @xml = (
		SELECT @FunctionId			AS '@fi'				
				,@IsActive			AS '@i'								
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')		
		
	SET @endRun		= GETDATE()  
	SET @duration	= DATEDIFF(millisecond, @startRun, @endRun)   

	EXEC dbo.NAP_RunSP_WriteLog
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Function_UpdateStatus',
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
GRANT EXECUTE ON [dbo].[NAP_Function_UpdateStatus] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_UpdateStatus] TO [vnteam] AS [dbo]