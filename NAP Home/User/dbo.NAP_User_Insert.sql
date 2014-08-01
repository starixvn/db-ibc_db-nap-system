USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_User_Insert]    Script Date: 8/1/2014 1:51:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_User_Insert]
    @UserId             INT
    ,@username			VARCHAR(30) = null
    ,@GroupId           SMALLINT
    ,@CreatedBy			INT
    ,@CreatedDate       DATETIME
    ,@CurrentUserId		INT
    ,@CurrentSiteId		TINYINT
	,@LogDate			DATETIME
	,@LoginIP			VARCHAR(30)		=   ''
	,@Language			VARCHAR(10)		=   'en-us'
	,@ErrCode			INT				=   0		OUTPUT
	,@ErrMsg			NVARCHAR(1000)	=   ''		OUTPUT 
AS

/*  
 * Created	: 20120820@Edward
 * Task		: Insert user
 * DB		: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 	
	*** WRITE LOG template:
	Main	:	<root><xml path="r" />
					<row item="Username" alias="u" />
					<row item="UserId" alias="ui" />
					<row item="GroupId" alias="gi" />	
					<row item="GroupName" alias="g" />			
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
    
	-- Add new user
	INSERT INTO Users(UserId, GroupId, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
	VALUES(@UserId, @GroupId, @CreatedBy, @CreatedDate, @CreatedBy, @CreatedDate)
    
	-- Check error
    IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Fail to add new UserId ' + CONVERT(VARCHAR(10), @UserId)
			RETURN
		END		

	-- Write log
	SET @xml = (
		SELECT @UserId			AS '@ui'
				,@username		AS '@u'
				,@GroupId		AS '@gi'
				,g.GroupName	AS '@g'
		FROM Users AS u WITH(NOLOCK)
		INNER JOIN Groups AS g WITH(NOLOCK) ON u.GroupId = g.GroupId
		WHERE u.userid = @UserId 	
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_User_Insert',
	@ObjectId		= @UserId,
	@ObjectTypeId	= 1,					-- Object type : User
	@Language		= @Language,
	@SiteID			= @CurrentSiteId,
	@IP				= @LoginIP,
	@Date			= @LogDate,
	@Data			= @logSPData,
	@OldData		= @logSPDataOld,
	@Duration		= @Duration
END

GO
GRANT EXECUTE ON [dbo].[NAP_User_Insert] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_Insert] TO [vnteam] AS [dbo]