USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Group_AssignFunction]    Script Date: 8/1/2014 1:36:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Group_AssignFunction]
	@GroupId			INT
	,@SiteId			INT
	,@Value				NVARCHAR(4000)
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
 * Created	: 20120814@Edward
 * Task		: Assign function to group
 * DB	: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
	• @Value	: is xml 
		<ROOT>
			<FunctionPolicy FunctionId="1" SiteId="1" Policy="2"></FunctionPolicy>
			<FunctionPolicy FunctionId="2" SiteId="1" Policy="2"></FunctionPolicy>
		</ROOT>
	• @ErrCode	:
		= 0: super create master successfully.
		> 0: Specific Error.

	*** WRITE LOG template:
	Main: 
		<root><xml path="r" />
				<row item="GroupId" alias="g" />
				<row item="SiteId" alias="s" />
		</root>
	Sub: 
		<root><xml path="r/z" />
				<row item="FunctionId" alias="f" />
				<row item="Policy" alias="p" />
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
	-- write log before update
	DECLARE @tempData VARCHAR(5000)
	
	-- Data xml for write log
	SELECT FunctionId, Policy,GroupId
	INTO #TempData
	FROM GroupFunction AS gf WITH(NOLOCK)
	WHERE	gf.GroupId		= @GroupId
			AND gf.SiteId	= @SiteId

	SET @xml = (
		SELECT @SiteId		AS '@s'
				,@GroupId	AS '@g'
				,(
					SELECT gf.FunctionId	AS '@f'
						,gf.Policy			AS '@p'
					FROM  #TempData	 AS gf				
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')

	-- Get data from @Value and insert to table
	DECLARE @TableFunctionPolicy TABLE(FunctionId INT, SiteId INT, Policy INT)
   
	SET @xml = CONVERT(XML, @Value)
	INSERT INTO @TableFunctionPolicy(FunctionId, siteid, policy)
	SELECT	T.C.value('./@FunctionId', 'smallint')
			,T.C.value('./@SiteId', 'tinyint')
			,T.C.value('./@Policy', 'tinyint')
	FROM @xml.nodes('/ROOT/FunctionPolicy') as [T](C) --T: table, C: column		
	
	--Update Policy = 0 for function not set to group
	UPDATE dbo.GroupFunction
    SET Policy        =   0
        ,ModifiedBy   =   @ModifiedBy
        ,ModifiedDate =   @ModifiedDate    
    WHERE 
		GroupId = @GroupId AND SiteId = @SiteId
		AND FunctionId NOT IN (	SELECT FunctionId
								FROM @TableFunctionPolicy )
	
	--Update policy for function of group
	UPDATE dbo.GroupFunction
    SET Policy			=	Temp.Policy
        ,ModifiedBy		=	@ModifiedBy
        ,ModifiedDate	=	@ModifiedDate
    FROM @TableFunctionPolicy AS Temp
    WHERE 
		dbo.GroupFunction.GroupId = @GroupId
		AND dbo.GroupFunction.FunctionId = Temp.FunctionId 
    
    --Insert new policy for function of group
    INSERT INTO dbo.GroupFunction (
        GroupId
        , FunctionId
        , SiteId
        , Policy
        , CreatedBy
        , CreatedDate
        , ModifiedBy
        , ModifiedDate
    )
    SELECT @GroupId
        ,Temp.FunctionId
        ,Temp.SiteId
        ,Temp.Policy
        ,@ModifiedBy
        ,@ModifiedDate
        ,@ModifiedBy
        ,@ModifiedDate
    FROM @TableFunctionPolicy AS Temp
    WHERE NOT EXISTS 
        (
             SELECT TOP(1) *
                FROM dbo.GroupFunction AS gf WITH (NOLOCK)
                WHERE gf.GroupId=@GroupId
                AND gf.FunctionId= Temp.FunctionId				
        )
        
	IF @@ERROR > 0
		BEGIN
			SELECT @ErrCode = 1, 
					@ErrMsg = 'Fail to assign function of the GroupId '+ CONVERT(VARCHAR(10), @GroupId)
			RETURN
		END		

	-- write log after update
	SET @xml = (
		SELECT @SiteId		AS '@s'
				,@GroupId	AS '@g'
				,(					
					SELECT gf.FunctionId	AS '@f'
						,gf.Policy			AS '@p'
					FROM GroupFunction AS gf WITH (NOLOCK)
					LEFT JOIN #TempData t ON gf.FunctionId = t.FunctionId AND gf.Policy = t.Policy
					WHERE gf.GroupId = @GroupId
					AND gf.SiteId = @SiteId
					AND t.GroupId IS NULL
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Group_AssignFunction',
	@ObjectId		= @GroupId,
	@ObjectTypeId	= 2,			--Object type : Group
	@Language		= @Language,
	@SiteID			= @CurrentSiteId,
	@IP				= @LoginIP,
	@Date			= @LogDate,
	@Data			= @logSPData,
	@OldData		= @logSPDataOld,
	@Duration		= @Duration
END

GO
GRANT EXECUTE ON [dbo].[NAP_Group_AssignFunction] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Group_AssignFunction] TO [vnteam] AS [dbo]