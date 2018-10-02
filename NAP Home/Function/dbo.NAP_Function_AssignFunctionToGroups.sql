/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Function_AssignFunctionToGroups]
     @FunctionId        INT
	,@SiteId            INT
    ,@Value             NVARCHAR(MAX)
    ,@ModifiedBy        INT
    ,@ModifiedDate      DATETIME
    ,@CurrentUserId		INT
    ,@CurrentSiteId		INT
	,@LogDate			DATETIME
	,@LoginIP			VARCHAR(30)		=   ''
	,@Language			VARCHAR(20)		=   'en-us'
	,@ErrCode			INT				=   0		OUTPUT
	,@ErrMsg			NVARCHAR(1000)	=   ''		OUTPUT 
AS
/*  
 * Created: Edward
 * Task : Assign function to groups
 * DB: DBPOL-NAP_UserControl
 *  
 * Revisions:     
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	
 * Param's Explanation: 
		- Value : '<ROOT><FunctionPolicy GroupId='{0}' Policy='{1}'></FunctionPolicy></ROOT>'
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
    
	-- Write log before assign permission
	SELECT gf.FunctionId, gf.Policy,gf.GroupId,g.GroupName
	INTO #TempData
	FROM dbo.NAP_GroupFunction	AS gf WITH(NOLOCK)
		INNER JOIN dbo.NAP_Groups	AS g WITH (NOLOCK) ON gf.GroupId = g.GroupId
	WHERE gf.FunctionId = @FunctionId

	SET @xml = (
		SELECT @FunctionId		AS '@f'				
				,(
					SELECT gf.GroupId		AS '@gi'
						,gf.Policy			AS '@p'
						,gf.GroupName		AS '@g'
					FROM  #TempData	 AS gf				
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld	= REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	
	-- Read information from @Value and insert into temp table
	DECLARE @TblFuncPolicy TABLE(GroupId INT, Policy INT)
   
    DECLARE @DocHandler int

	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @Value

	INSERT INTO @TblFuncPolicy (GroupId,Policy)	
	SELECT Data.GroupId,Data.Policy
    FROM OPENXML (@DocHandler, '/ROOT/FunctionPolicy',1) 
    WITH (GroupId	INT
         ,Policy    INT
    ) AS Data

	EXEC sp_xml_removedocument @DocHandler

	--Update policy for users assigned the function already
	UPDATE dbo.NAP_GroupFunction
	SET	
		Policy			= 1
		,ModifiedBy		= @ModifiedBy
		,ModifiedDate	= @ModifiedDate
	WHERE
		FunctionId = @FunctionId
		AND SiteId = @SiteId
		AND GroupId IN (SELECT GroupId FROM @TblFuncPolicy WHERE Policy = 1)

	UPDATE dbo.NAP_GroupFunction
	SET	
		Policy			= 2
		,ModifiedBy		= @ModifiedBy
		,ModifiedDate	= @ModifiedDate
	WHERE
		FunctionId = @FunctionId
		AND SiteId = @SiteId
		AND GroupId IN (SELECT GroupId FROM @TblFuncPolicy WHERE Policy = 2)

	--Assigns the fucntion to new users
    INSERT INTO dbo.NAP_GroupFunction (
		GroupId
        ,FunctionId
        ,SiteId
        ,Policy
        ,CreatedBy
        ,CreatedDate
        ,ModifiedBy
        ,ModifiedDate
    )
    SELECT
		 Temp.GroupId
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
		FROM dbo.NAP_GroupFunction AS uf WITH (NOLOCK)
		WHERE uf.GroupId = Temp.GroupId
		AND uf.FunctionId = @FunctionId
	)    
    
	-- Check error
    IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Failed to assign function to group [FunctionId='+ COALESCE(CAST(@FunctionId AS VARCHAR(10)), SPACE(1)) + ']'
			RETURN
		END		

	-- write log after update
	SET @xml = (
		SELECT @FunctionId		AS '@f'				
				,(					
					SELECT gf.GroupId			AS '@gi'
							,gf.Policy			AS '@p'
							,g.GroupName		AS '@g'
					FROM dbo.NAP_GroupFunction AS gf WITH (NOLOCK)
						LEFT JOIN #TempData t ON gf.GroupId = t.GroupId AND gf.Policy = t.Policy
						INNER JOIN dbo.NAP_Groups	AS g WITH (NOLOCK) ON gf.GroupId = g.GroupId
					WHERE gf.FunctionId = @FunctionId			
					AND t.GroupId IS NULL
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC dbo.NAP_RunSP_WriteLog 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Function_AssignFunctionToGroups',
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
GRANT EXECUTE ON [dbo].[NAP_Function_AssignFunctionToGroups] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Function_AssignFunctionToGroups] TO [vnteam] AS [dbo]