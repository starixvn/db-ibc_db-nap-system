ALTER PROCEDURE [dbo].[NAP_Function_AssignFunctionToUsers]
     @FunctionId		INT
	,@SiteId			INT
    ,@Value				NVARCHAR(MAX)
    ,@ModifiedBy		INT
    ,@ModifiedDate		DATETIME
    ,@CurrentUserId		INT
    ,@CurrentSiteId		INT
	,@LogDate			DATETIME
	,@LoginIP			VARCHAR(30)		=   ''
	,@Language			VARCHAR(20)		=   'en-us'
	,@ErrCode			INT				=   0		OUTPUT
	,@ErrMsg			NVARCHAR(1000)	=   ''		OUTPUT 
AS
/*  
 * Created: 20121101@Lewis
 * Task : Assign function to users
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
		- Value : '<ROOT><FunctionPolicy UserId='{0}' Policy='{1}'></FunctionPolicy></ROOT>'
*/
BEGIN
    SET NOCOUNT ON    
   
	-- For write log
    DECLARE 
		@startRun		DATETIME  
		,@endRun		DATETIME  
		,@duration		INT
		,@logSPData		VARCHAR(5000)
		,@logSPDataOld	VARCHAR(5000)	 
		,@xml			XML       
    
	SET @startRun = GETDATE()	  
    
	--Write log before update
	SELECT uf.FunctionId, uf.Policy,uf.UserId,cu.username 
	INTO #TempData
	FROM UserFunction AS uf WITH(NOLOCK)
	INNER JOIN bodb02.dbo.Customer AS cu WITH(NOLOCK) ON uf.UserId = cu.custid
	WHERE uf.FunctionId = @FunctionId

	SET @xml = (
		SELECT @FunctionId				AS '@f'				
				,(
					SELECT uf.UserId	AS '@ui'
						,uf.Policy		AS '@p'
						,uf.username	AS '@u'
					FROM  #TempData		AS uf				
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	
	
	SET @logSPDataOld	= REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	
	-- Read information from @Value and insert into temp table
	DECLARE @TblFuncPolicy TABLE(UserId INT, Policy INT)
   
    DECLARE @DocHandler int

	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @Value

	INSERT INTO @TblFuncPolicy (UserId,Policy)	
	SELECT Data.UserId,Data.Policy
    FROM OPENXML (@DocHandler, '/ROOT/FunctionPolicy',1) 
    WITH (UserId	INT
         ,Policy    INT
    ) AS Data

	EXEC sp_xml_removedocument @DocHandler

	--Update policy for users assigned the function already
	UPDATE dbo.UserFunction
	SET	
		Policy			= 1
		,ModifiedBy		= @ModifiedBy
		,ModifiedDate	= @ModifiedDate
	WHERE
		FunctionId = @FunctionId
		AND SiteId = @SiteId
		AND UserId IN (SELECT UserId FROM @TblFuncPolicy WHERE Policy = 1)

	UPDATE dbo.UserFunction
	SET	
		Policy			= 2
		,ModifiedBy		= @ModifiedBy
		,ModifiedDate	= @ModifiedDate
	WHERE
		FunctionId = @FunctionId
		AND SiteId = @SiteId
		AND UserId IN (SELECT UserId FROM @TblFuncPolicy WHERE Policy = 2)

	--Assigns the fucntion to new users
    INSERT INTO dbo.UserFunction (
		UserId
        ,FunctionId
        ,SiteId
        ,Policy
        ,CreatedBy
        ,CreatedDate
        ,ModifiedBy
        ,ModifiedDate
    )
    SELECT
		 Temp.UserId
        ,@FunctionId
        ,@SiteId
        ,Temp.Policy
        ,@ModifiedBy
        ,@ModifiedDate
        ,@ModifiedBy
        ,@ModifiedDate
    FROM @TblFuncPolicy AS Temp
    WHERE NOT EXISTS          
	(               
		SELECT TOP(1) *
		FROM dbo.UserFunction AS uf WITH (NOLOCK)
		WHERE uf.UserId = Temp.UserId
		AND uf.FunctionId = @FunctionId
	)    
    
    IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Failed to assign function to users [FunctionId=' + COALESCE(CAST(@FunctionId AS VARCHAR(10)), SPACE(1)) + ']'
			RETURN
		END		

	-- write log after update
	SET @xml = (
		SELECT @FunctionId		AS '@f'				
				,(					
					SELECT uf.UserId		AS '@ui'
							,uf.Policy		AS '@p'
							,cu.username		AS '@u'
					FROM UserFunction AS uf WITH (NOLOCK)
					LEFT JOIN #TempData AS t ON uf.UserId = t.UserId AND uf.Policy = t.Policy
					INNER JOIN bodb02.dbo.Customer AS cu WITH(NOLOCK) ON uf.UserId = cu.custid
					WHERE uf.FunctionId = @FunctionId			
					AND t.UserId IS NULL
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Function_AssignFunctionToUsers',
	@ObjectId		= @FunctionId,
	@ObjectTypeId	= 4,			--Object type : Function
	@Language		= @Language,
	@SiteID			= @CurrentSiteId,
	@IP				= @LoginIP,
	@Date			= @LogDate,
	@Data			= @logSPData,
	@OldData		= @logSPDataOld,
	@Duration		= @Duration
END

GO
GRANT EXECUTE ON [dbo].[NAP_Function_AssignFunctionToUsers] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_AssignFunctionToUsers] TO [vnteam] AS [dbo]