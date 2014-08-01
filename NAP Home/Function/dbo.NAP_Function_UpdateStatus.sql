USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Function_UpdateStatus]    Script Date: 8/1/2014 1:34:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
 * Created	: 20120810@Kos
 * Task		: Update status of function
 * DB		: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
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
		FROM Functions AS f WITH (NOLOCK)		
		WHERE f.FunctionId =  @FunctionId
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')

	-- Update status of function
	UPDATE dbo.Functions 
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

	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
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