/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_GlobalLeagueGroupIns]
    @LeagueGroups VARCHAR(MAX),
    @Market TINYINT,
    @GlobalSetting VARCHAR(MAX) = '',	
	@SportType SMALLINT = 1,
	@UserID INT,
	@IP	VARCHAR(40),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
	Created: 20251114@Johnson	
	Task: Add global league group setting
	DB: DBCUST.CustDB

	Revisions:
		- 20251114@Johnson: TO Monitor Control By League Group [Redmine: 243977]

	Parameter's explaination:
		@GlobalSetting: 
			'<ROOT>
				<r MaxTO="100" ProfileID  = "1" />
				<r MaxTO="150" ProfileID  = "2"/>
			</ROOT>'
		@Market: 1: Malay, 2: 789, 3: others	
		@LeagueGroups: 
			'<ROOT>
				<r ID="0" LeagueGroup = "None"/>
				<r ID="1" LeagueGroup = "Major League"/>
			</ROOT>'
*/
BEGIN
    SET NOCOUNT ON;

	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT,
			@FunctionKey NVARCHAR(50),
			@Remark		VARCHAR(500)

	DECLARE @MaxTurnover_Log VARCHAR(1000),
			@LeagueGroup_Log VARCHAR(MAX)
			
	DECLARE @tmpSetting TABLE (ProfileID SMALLINT, MaxTurnover MONEY)
	DECLARE @tmpLeagueGroup TABLE (LeagueGroupID INT PRIMARY KEY, LeagueGroup VARCHAR(200))
	CREATE TABLE #tblCust (CustID INT , IsGroupHeadLine BIT, isFinished BIT DEFAULT (0) PRIMARY KEY(CustID, IsGroupHeadLine))	
	DECLARE @tmpCust TABLE (CustID INT, IsGroupHeadLine BIT PRIMARY KEY(CustID, IsGroupHeadLine))

	SET	@startRun = GETDATE()
	
	IF @SportType = 1 
		SET @FunctionKey = 'GlobalLeagueGroupSetting_Soccer'

	--Check permission 
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission @UserId=@UserID,@SiteKey='CustomerManagement',@FunctionKey=@FunctionKey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN	

	INSERT INTO @tmpLeagueGroup (LeagueGroupID,LeagueGroup)
	SELECT 
		T.c.value('@ID', 'INT') AS LeagueGroupID,
		T.c.value('@LeagueGroup', 'VARCHAR(200)') AS LeagueGroup
	FROM 
		(SELECT CAST(@LeagueGroups AS XML) AS LeagueGroupsXML) AS A
	CROSS APPLY 
		LeagueGroupsXML.nodes('/ROOT/r') AS T(c)

	SELECT @ErrMsg = ''

	SELECT  @ErrMsg = STUFF((
		SELECT ',' + LeagueGroup 
		FROM @tmpLeagueGroup t
		WHERE EXISTS (SELECT 1 
					FROM TOControl_LeagueGroupSetting cs WITH (NOLOCK)  
					WHERE cs.LeagueGroupID = t.LeagueGroupID
						AND Market = @Market 
						AND SportType = @SportType)
		FOR XML PATH('')),1,1,'')

	IF @ErrMsg <> ''	
	BEGIN
			SELECT @ErrCode = 102, @ErrMsg = 'The setting of these league groups already existed: ' + @ErrMsg + '.'
			RETURN
	END			

	INSERT INTO @tmpSetting (ProfileID, MaxTurnover)
	SELECT ProfileID, MaxTurnover
	FROM 
		(
			SELECT 
				T.c.value('@ProfileID', 'SMALLINT') AS ProfileID,
				T.c.value('@MaxTO', 'MONEY') AS MaxTurnover
			FROM 
				(SELECT CAST(@GlobalSetting AS XML) AS GlobalSettingXML) AS A
			CROSS APPLY 
				GlobalSettingXML.nodes('/ROOT/r') AS T(c)
		) AS S
	WHERE S.ProfileID IN (SELECT ProfileID FROM TOControl_Profile WITH (NOLOCK) WHERE SportType = @SportType)

	INSERT INTO TOControl_LeagueGroupSetting (LeagueGroupID, Market, SportType, ProfileID, MaxTurnover)
	SELECT lg.LeagueGroupID, @Market, @SportType, ProfileID, MaxTurnover
	FROM @tmpSetting
		CROSS APPLY (
			SELECT lg.LeagueGroupID
			FROM @tmpLeagueGroup lg
		) lg

	IF @@ERROR > 0 
	BEGIN
		SELECT @ErrCode = 103, @ErrMsg = 'Adding failed.'
		RETURN;		
	END

	INSERT INTO #tblCust (CustID, IsGroupHeadLine)
	SELECT DISTINCT cs.CustID, cs.IsGroupHeadLine
	FROM TOControl_GlobalSetting cs WITH (NOLOCK)
		INNER JOIN Customer c WITH(NOLOCK) ON cs.CustID = c.CustID
	WHERE cs.SportType = @SportType 
		AND cs.LeagueGroupID = -1 -- Default Global Setting
		AND c.site IN (SELECT site FROM dbo.f_TOControl_GetSiteByMarket(@Market))

	WHILE(1=1)
	BEGIN
		UPDATE TOP (1000) t
		SET t.isFinished = 1
		OUTPUT DELETED.CustID, DELETED.IsGroupHeadLine INTO @tmpCust(CustID, IsGroupHeadLine)
		FROM #tblCust t		
		WHERE t.isFinished = 0

		IF @@ROWCOUNT = 0 BREAK;

		INSERT INTO [dbo].[TOControl_GlobalSetting]
           ([CustID]
           ,[MaxTurnOver]
           ,[Sporttype]
           ,[IsGroupHeadLine]
           ,[ProfileID]
           ,[IsGlobalLockTOLimit]
		   ,[LeagueGroupID]
           ,[IsLeagueGroupLock]
           ,[RepUpdateTime]
           )
		SELECT tc.CustID
			  ,s.MaxTurnover
			  ,@SportType
			  ,tc.IsGroupHeadLine
			  ,s.ProfileID
			  ,0 -- IsGlobalLockTOLimit
			  ,s.LeagueGroupID
			  ,0 -- IsLeagueGroupLock
			  ,dbo.f_GetDateTime2()
		FROM @tmpCust tc
			CROSS APPLY (
				SELECT lg.LeagueGroupID, s.ProfileID, s.MaxTurnover
				FROM @tmpSetting s
					CROSS APPLY (
						SELECT lg.LeagueGroupID
						FROM @tmpLeagueGroup lg
					) lg
			) s
		WHERE NOT EXISTS (
			SELECT 1 
			FROM dbo.TOControl_GlobalSetting gs WITH (NOLOCK)
			WHERE gs.CustID = tc.CustID 
				AND gs.IsGroupHeadLine = tc.IsGroupHeadLine
				AND gs.SportType = @SportType
				AND gs.LeagueGroupID = s.LeagueGroupID
				AND gs.ProfileID = s.ProfileID
		)

		DELETE @tmpCust
	END

	SET @MaxTurnover_Log = (
						SELECT STUFF((SELECT ',' + CAST(pf.ProfileName AS VARCHAR(50)) + '="' + CAST(m.MaxTurnover AS VARCHAR(50)) + '"'
						FROM @tmpSetting m
							INNER JOIN dbo.TOControl_Profile pf WITH (NOLOCK) ON m.ProfileID = pf.ProfileID
						FOR XML PATH('')),1,1,'')
					)
	SELECT @MaxTurnover_Log = REPLACE(REPLACE(REPLACE(@MaxTurnover_Log , '&amp;',''), ' ', ''), ',', ' ')

	SELECT @LeagueGroup_Log = (
						SELECT STUFF((SELECT ',' + CAST(lg.LeagueGroup AS VARCHAR(200))
						FROM @tmpLeagueGroup lg
						FOR XML PATH('')),1,1,'')
					)
					
	DECLARE @LogData NVARCHAR(4000)
	SELECT @LogData = '<NAP_TOControl_GlobalLeagueGroupSettingInsert Market="' + COALESCE(CAST(@Market AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'LeagueGroups="' + COALESCE(CAST(@LeagueGroup_Log as varchar(50)),space(1)) + '" ' 										
					+ 'SportType="' + COALESCE(CAST(@SportType AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ COALESCE(CAST(@MaxTurnover_Log AS VARCHAR(MAX)), SPACE(1)) + ' ' 				
					+ 'IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1)) + '" '
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" />'
														
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)

	-- WRITE LOG
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@Userid = @UserID,					
					@ActionID = 95127,
					@TrackingValue = @LogData,
					@Duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @Remark = 'ErrMsg=' + LEFT(ERROR_MESSAGE(), 350)

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@Userid = @UserID,					
					@ActionID = 95127,
					@TrackingValue = @LogData,
					@Duration = @duration,
					@Doing = @Remark
	END CATCH
END