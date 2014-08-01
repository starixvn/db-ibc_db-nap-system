USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_User_AssignFunction]    Script Date: 8/1/2014 1:45:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_User_AssignFunction]
    @UserId             INT
	,@SiteId            INT
    ,@Value             VARCHAR(MAX)
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
 * Created: 20120820@Edward
 * Task : Assign function to user
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
		- Value : '<ROOT><FunctionPolicy SiteId="4" FunctionId="4" Policy="1"></FunctionPolicy></ROOT>'  
	
	*** WRITE LOG template:
	main:	<root><xml path="r" />
					<row item="SiteId" alias="s" />
					<row item="UserId" alias="u" />
			</root>
	sub:	<root><xml path="r/z" />
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
	  
	SELECT FunctionId, Policy, UserId
	INTO #TempData
	FROM UserFunction uf WITH(NOLOCK)
	WHERE uf.UserId			= @UserId	
			AND uf.SiteId	= @SiteId

    -- Write log before assign permission	
	SET @xml = (
		SELECT @SiteId		AS '@s'
				,@UserId	AS '@u'
				,(
					SELECT 						
						FunctionId	AS '@f'
						,Policy		AS '@p'
					FROM #TempData					
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')

	-- Read information from @Value and insert into temp table
	DECLARE @TableFunctionPolicy TABLE(FunctionId smallint, SiteId tinyint, Policy tinyint)

	SET @xml = CONVERT(XML, @Value)
	INSERT INTO @TableFunctionPolicy(FunctionId, siteid, policy)
	SELECT	T.C.value('./@FunctionId', 'smallint')
			,T.C.value('./@SiteId', 'tinyint')
			,T.C.value('./@Policy', 'tinyint')
	FROM @xml.nodes('/ROOT/FunctionPolicy') as [T](C) --T: table, C: column	

	--Update Policy = 0 for function not set to user
    UPDATE dbo.UserFunction
    SET Policy        =   0
        ,ModifiedBy   =   @ModifiedBy
        ,ModifiedDate =   @ModifiedDate    
    WHERE 
		UserId = @UserId AND SiteId = @SiteId
		AND FunctionId NOT IN (	SELECT FunctionId
							FROM @TableFunctionPolicy )

	--Update policy for function of user
	UPDATE dbo.UserFunction
    SET Policy			=	Temp.Policy
        ,ModifiedBy		=	@ModifiedBy
        ,ModifiedDate	=	@ModifiedDate
    FROM @TableFunctionPolicy AS Temp
    WHERE dbo.UserFunction.UserId	=	@UserId
    AND dbo.UserFunction.FunctionId	=	Temp.FunctionId   
    
	--Insert new policy for function of user
    INSERT INTO dbo.UserFunction (
        UserId
        , FunctionId
        , SiteId
        , Policy
        , CreatedBy
        , CreatedDate
        , ModifiedBy
        , ModifiedDate
    )
    SELECT
        @UserId
        ,Temp.FunctionId
        ,Temp.SiteId
        ,Temp.Policy
        ,@ModifiedBy
        ,@ModifiedDate
        ,@ModifiedBy
        ,@ModifiedDate
    FROM @TableFunctionPolicy AS Temp
    WHERE  NOT EXISTS          
           (               
                SELECT TOP(1) *
                FROM dbo.UserFunction AS uf WITH(NOLOCK)
                WHERE uf.UserId = @UserId
                AND uf.FunctionId = Temp.FunctionId
            )    
    
	-- Check error
    IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Fail to assign function UserId '+ CONVERT(VARCHAR(10), @UserId)
			RETURN
		END		


	-- write log after update
	SET @xml = (
		SELECT @SiteId		AS '@s'
				,@UserId	AS '@u'
				,(
					SELECT 						
						uf.FunctionId	AS '@f'
						,uf.Policy		AS '@p'
					FROM UserFunction uf WITH(NOLOCK)
					LEFT JOIN #TempData t ON uf.FunctionId = t.FunctionId AND uf.Policy = t.Policy
					WHERE uf.UserId = @UserId	
					AND uf.SiteId = @SiteId
					AND t.UserID IS NULL
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData	= REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun		= GETDATE()  
	SET @duration	= DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_User_AssignFunction',
	@ObjectId		= @UserId,
	@ObjectTypeId	= 1,			--Object type : User
	@Language		= @Language,
	@SiteID			= @CurrentSiteId,
	@IP				= @LoginIP,
	@Date			= @LogDate,
	@Data			= @logSPData,
	@OldData		= @logSPDataOld,
	@Duration		= @Duration
		
END

GO
GRANT EXECUTE ON [dbo].[NAP_User_AssignFunction] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_AssignFunction] TO [vnteam] AS [dbo]