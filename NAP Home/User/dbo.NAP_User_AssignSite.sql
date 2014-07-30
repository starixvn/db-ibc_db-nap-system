 ALTER PROCEDURE [dbo].[NAP_User_AssignSite]
    @UserId             INT
    ,@Value             NVARCHAR(MAX)
    ,@ModifiedBy        INT
    ,@ModifiedDate      DATETIME
    ,@CurrentUserId		INT
    ,@CurrentSiteId		INT
	,@LogDate			DATETIME
	,@LoginIP			VARCHAR(30)		=	''
	,@Language			VARCHAR(20)		=	'en-us'
	,@ErrCode			INT				=	0		OUTPUT
	,@ErrMsg			NVARCHAR(1000)	=	''		OUTPUT 
AS
/*  
 * Created: 20120820@Edward
 * Task : Assign site to user
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
		- Value : '<ROOT><SiteLevel SiteId="4" Level="3" ></SiteLevel></ROOT>'
	
*** WRITE LOG template:
	main: <root><xml path="r" /><row item="UserId" alias="u" /></root>	sub: <root><xml path="r/z" />
			<row item="SiteId" alias="si" />
			<row item="SiteName" alias="s" />
			<row item="Level" alias="l" />
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
	-- Write log before assign permission
	SET @xml = (
		SELECT @UserId as '@u'
				,(
					SELECT s.SiteId			AS '@si'
							,s.SiteName		AS '@s'
							,us.Level		AS '@l'
							,us.IsActive	AS '@i'
					FROM UserSite AS us WITH(NOLOCK)
					INNER JOIN Sites  AS s WITH(NOLOCK) ON s.SiteId = us.SiteId
					WHERE us.UserId = @UserId		
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')
	
	-- Read information from @value and insert into temp table
	DECLARE @TableSiteLevel	TABLE(SiteId INT, [Level] INT) 
   
    DECLARE @DocHandler int

	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @Value
	
	INSERT INTO @TableSiteLevel(SiteId,[Level])
	SELECT Data.SiteId,Data.[Level]
	FROM OPENXML (@DocHandler, '/ROOT/SiteLevel',1) 
	WITH (SiteId  INT
		,[Level]  INT
	) AS Data	

	EXEC sp_xml_removedocument @DocHandler    	

	--Remove all user function permissions if downgrade
	UPDATE dbo.UserFunction
	SET Policy = 0
	WHERE UserId = @UserId
	AND SiteId IN (
					SELECT us.SiteId
					FROM UserSite AS us WITH (NOLOCK),@TableSiteLevel AS tsl
					WHERE us.SiteId=tsl.SiteId
					AND us.UserId=@UserId
					AND us.Level > tsl.Level		
				)	
	
	--Update Level = 0 for site not set to user
	UPDATE dbo.UserSite
    SET UserSite.IsActive		= 0
        ,UserSite.ModifiedBy	= @ModifiedBy
        ,UserSite.ModifiedDate	= @ModifiedDate    
    WHERE UserSite.UserId		= @UserId
    AND UserSite.SiteId NOT IN (SELECT SiteId FROM @TableSiteLevel)
	
	--Update Level for site of user
	UPDATE dbo.UserSite
    SET UserSite.[Level]		= tsl.[Level]
        ,UserSite.IsActive		= 1
        ,UserSite.ModifiedBy	= @ModifiedBy
        ,UserSite.ModifiedDate	= @ModifiedDate
    FROM @TableSiteLevel AS tsl
    WHERE UserSite.UserId		= @UserId
    AND UserSite.SiteId			= tsl.SiteId
    
	--Assign new site to user
    INSERT dbo.UserSite (
        UserId
        ,SiteId
        ,[Level]
        ,IsActive
        ,CreatedBy
        ,CreatedDate
        ,ModifiedBy
        ,ModifiedDate
     )
    SELECT @UserId
        ,Temp.SiteId
        ,Temp.[Level]
        ,1
        ,@ModifiedBy
        ,@ModifiedDate
        ,@ModifiedBy
        ,@ModifiedDate
    FROM @TableSiteLevel AS Temp
    WHERE NOT EXISTS
    (
        SELECT TOP(1) *
        FROM dbo.UserSite AS us WITH (NOLOCK)
        WHERE us.UserId	=	@UserId
        AND us.SiteId	=	Temp.SiteId            
    )
    
	--For each site, if user is site admin then assign all functions to him/her
	UPDATE dbo.UserFunction
	SET Policy = 1
	WHERE
		UserId = @UserId
		AND	FunctionId IN (
							SELECT FunctionId
							FROM
								@TableSiteLevel tsl
								INNER JOIN dbo.Functions f ON tsl.SiteId = f.SiteId
							WHERE
								tsl.[Level] IN (50, 100) -- Site admin: 50, Portal admin: 100
								AND f.CRUD = 0
						)

	UPDATE dbo.UserFunction
	SET Policy = 2
	WHERE
		UserId = @UserId
		AND FunctionId IN (
							SELECT FunctionId
							FROM
								@TableSiteLevel tsl
								INNER JOIN dbo.Functions f ON tsl.SiteId = f.SiteId
							WHERE
								tsl.[Level] IN (50, 100) -- Site admin: 50, Portal admin: 100
								AND f.CRUD = 1
		)

	INSERT dbo.UserFunction
	(
		UserId,
		FunctionId,
		SiteId,
		Policy,
		CreatedDate,
		ModifiedDate
	)
	SELECT
		@UserId,
		f.FunctionId,
		f.SiteId,
		policy = CASE f.CRUD
			WHEN 0 THEN 1
			WHEN 1 THEN 2
		END,
		@startRun,
		@startRun
	FROM
		@TableSiteLevel tsl
		INNER JOIN dbo.Functions f ON tsl.SiteId = f.SiteId
	WHERE
		tsl.[Level] IN (50, 100) -- Site admin: 50, Portal admin: 100
		AND NOT EXISTS (
						SELECT 1
						FROM dbo.UserFunction uf
						WHERE uf.UserId = @UserId AND uf.FunctionId = f.FunctionId
					)

    IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Failed to assign site UserId '+ CONVERT(VARCHAR(10), @UserId)
			RETURN
		END		
	
	-- write log after update
	SET @xml = (
		SELECT @UserId as '@u'
				,(
					SELECT s.SiteId			AS '@si'
							,s.SiteName		AS '@s'
							,us.Level		AS '@l'
							,us.IsActive	AS '@i'
					FROM UserSite AS us WITH(NOLOCK)
					INNER JOIN Sites  AS s WITH(NOLOCK) ON s.SiteId = us.SiteId
					WHERE us.UserId = @UserId		
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_User_AssignSite',
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
GRANT EXECUTE ON [dbo].[NAP_User_AssignSite] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_AssignSite] TO [vnteam] AS [dbo]