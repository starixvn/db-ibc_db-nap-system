USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Site_InsertWithSiteURL]    Script Date: 8/1/2014 1:43:40 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Site_InsertWithSiteURL]
	@SiteId			INT								OUTPUT
	,@SiteName		VARCHAR(50)
	,@Description	VARCHAR(200)		= NULL
    ,@SiteURLs		VARCHAR(MAX)		= NULL
    ,@IsActive		BIT
    ,@Environment	VARCHAR(10)								-- Values: UAT | LIVE
	,@CurrentUserId	INT     
    ,@CurrentSiteId INT	
	,@LogDate		DATETIME
	,@LoginIP		VARCHAR(30)			= ''
	,@Language		VARCHAR(20)			= 'en-us'
	,@ErrCode		INT					= 0			OUTPUT 
	,@ErrMsg		NVARCHAR(1000)		= ''		OUTPUT 
AS
/*  
 * Created: 20120809@Edward
 * Changed: 20121009@Lewis
 *   + Removed @URL, @TestURL
 *   + Added @SiteURLs
 * Task: Add a new site
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation:
 *   + Urls sample:
		<ROOT>
			<SiteURL
				URL="http://www.example.com/"
				Environment="LIVE"
				IsDefault="1"
				IsActive="1">
			</SiteURL>
		</ROOT>
	• @ErrCode	:
		= 0: super create master successfully.
		> 0: Specific Error.

	*** WRITE LOG template:
	Main: 
		<root><xml path="r" />
			<row item="SiteId" alias="si" />
			<row item="SiteName" alias="s" />
			<row item="Description" alias="d" />
			<row item="IsActive" alias="i" />
			<row item="Environment" alias="e" />
		</root>
	Sub: 
		<root><xml path="r/z" />
				<row item="SiteURLId" alias="si" />				
				<row item="URL" alias="u" />
				<row item="Environment" alias="e" />
				<row item="IsDefault" alias="id" />
				<row item="IsActive" alias="ia" />
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

	-- create site

	INSERT INTO dbo.Sites (
          SiteName
        , Description
        , IsActive
        , Environment)
    VALUES(
          @SiteName
        , @Description
        , @IsActive
        , @Environment)
	
	SET @SiteId = SCOPE_IDENTITY()
	
	IF (@SiteId > 0)
		BEGIN
			
			EXEC NAP_Functions_GenerateNAPFunction @SiteId,@Environment

			-- assign portal admin is site admin in this site
			INSERT UserSite(
				UserId
				,SiteId
				,Level
				,IsActive
				,LastLoginDate
				,CreatedBy
				,CreatedDate
				,ModifiedBy
				,ModifiedDate)
			SELECT DISTINCT 
				us.UserId 
				,@SiteId
				,50
				,1
				,NULL
				,@CurrentUserId
				,@LogDate
				,@CurrentUserId
				,@LogDate
			FROM UserSite AS us WITH (NOLOCK)
			WHERE 
				us.Level = 100		-- Portal Admin
				AND SiteId = 1		-- NAP Admin Site ID
						
			-- assign permission for site admin		
			INSERT dbo.UserFunction
			(
				UserId,
				FunctionId,
				SiteId,
				Policy,		
				CreatedBy,	
				CreatedDate,
				ModifiedBy,
				ModifiedDate
			)
			SELECT
				us.UserId,
				f.FunctionId,
				@SiteId,
				policy = CASE f.CRUD
					WHEN 0 THEN 1
					WHEN 1 THEN 2
				END,
				@CurrentUserId,
				@LogDate,
				@CurrentUserId,
				@LogDate
			FROM 
				UserSite AS us WITH (NOLOCK)			
				INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON us.SiteId = f.SiteId
			WHERE
				us.SiteId = @SiteId
				AND	us.[Level] IN (50, 100) -- Site admin: 50, Portal admin: 100			
			
		END	

	-- insert site URL	
	SET @xml = CONVERT(XML, @SiteURLs)

	INSERT dbo.SiteURL (SiteId,URL, Environment, IsDefault, IsActive)
	SELECT	@SiteId
			,T.C.value('./@URL', 'VARCHAR(100)')
			,T.C.value('./@Environment', 'VARCHAR(10)')
			,T.C.value('./@IsDefault', 'BIT')
			,T.C.value('./@IsActive', 'BIT')
	FROM @xml.nodes('/ROOT/SiteURL') as [T](C) --T: table, C: column		

--#region Handles Errors and Logging

	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 1, 
				@ErrMsg = 'Failed to insert site [SiteId = ' + COALESCE(CAST(@SiteId AS VARCHAR(10)), '') + ']'
			RETURN
		END		

	--write log
	SET @xml = (
		SELECT @SiteId			AS '@si'	
				,@SiteName		AS '@s'
				,@Description	AS '@d'
				,@Environment	AS '@e'	
				,@IsActive		AS '@i'
				,(
					SELECT 	su.SiteURLId	AS '@si'
							,su.URL			AS '@u'	
							,su.Environment	AS '@e'
							,su.IsDefault	AS '@id'
							,su.IsActive	AS '@ia'
					FROM SiteURL AS su WITH (NOLOCK)
					WHERE SiteId = @SiteId
					FOR XML PATH('z'), TYPE	
				)
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Site_InsertWithSiteURL',
	@ObjectId		= @SiteId,
	@ObjectTypeId	= 3,			--Object type : Site
	@Language		= @Language,
	@SiteID			= @CurrentSiteId,
	@IP				= @LoginIP,
	@Date			= @LogDate,
	@Data			= @logSPData,
	@OldData		= @logSPDataOld,
	@Duration		= @Duration

END

GO
GRANT EXECUTE ON [dbo].[NAP_Site_InsertWithSiteURL] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_InsertWithSiteURL] TO [vnteam] AS [dbo]