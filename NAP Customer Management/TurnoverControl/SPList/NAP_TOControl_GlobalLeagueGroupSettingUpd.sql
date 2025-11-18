/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_GlobalLeagueGroupUpd]
    @LeagueGroupID INT,
	@LeagueGroup VARCHAR(200),
    @Market TINYINT,
    @GlobalSetting VARCHAR(MAX) = '',	
	@SportType SMALLINT = 1,
	@UserID INT,
	@IP	VARCHAR(40),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
	Created: 20251118@Johnson	
	Task: update global league group setting
	DB: DBCUST.CustDB

	Revisions:
		- 20251118@Johnson: TO Monitor Control By League Group [Redmine: 243977]

	Parameter's explaination:
		@GlobalSetting: 
			'<ROOT>
				<r MaxTO="100" ProfileID  = "1" />
				<r MaxTO="150" ProfileID  = "2"/>
			</ROOT>'
		@Market: 1: Malay, 2: 789, 3: others	
*/
BEGIN
    SET NOCOUNT ON;

	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT,
			@FunctionKey NVARCHAR(50),
			@Remark		VARCHAR(500)

	DECLARE @MaxTurnover_Log VARCHAR(1000),
			@MaxTurnoverOld_Log VARCHAR(1000)
	
	DECLARE @tmpSetting TABLE (ProfileID SMALLINT, MaxTurnover MONEY, MaxTurnover_Old MONEY)
	CREATE TABLE #tblCust (CustID INT , IsGroupHeadLine BIT, isFinished BIT DEFAULT (0) PRIMARY KEY(CustID, IsGroupHeadLine))	
	DECLARE @tmpCust TABLE (CustID INT, IsGroupHeadLine BIT PRIMARY KEY(CustID, IsGroupHeadLine))

	SET	@startRun = GETDATE()
	
	IF @SportType = 1 
		SET @FunctionKey = 'GlobalLeagueGroupSetting_Soccer'

	--Check permission 
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission @UserId=@UserID,@SiteKey='CustomerManagement',@FunctionKey=@FunctionKey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN	

	IF NOT EXISTS (SELECT 1 FROM TOControl_LeagueGroupSetting WITH (NOLOCK) 
				WHERE LeagueGroupID = @LeagueGroupID AND Market = @Market AND SportType = @SportType)
	BEGIN			
		RETURN
	END			

	INSERT INTO @tmpSetting (ProfileID, MaxTurnover)
	SELECT ProfileID, MaxTurnover
	FROM (
		SELECT 
			T.c.value('@ProfileID', 'SMALLINT') AS ProfileID,
			T.c.value('@MaxTO', 'MONEY') AS MaxTurnover
		FROM 
			(SELECT CAST(@GlobalSetting AS XML) AS GlobalSettingXML) AS A
		CROSS APPLY 
			GlobalSettingXML.nodes('/ROOT/r') AS T(c)		
	) S
	WHERE S.ProfileID IN (SELECT ProfileID FROM TOControl_Profile WITH (NOLOCK) WHERE SportType = @SportType)

	--Check any change setting
	IF NOT EXISTS (SELECT 1 
				FROM @tmpSetting t 
					INNER JOIN TOControl_LeagueGroupSetting cs WITH (NOLOCK) ON t.ProfileID = cs.ProfileID
				WHERE cs.LeagueGroupID = @LeagueGroupID 
					AND cs.Market = @Market 
					AND cs.SportType = @SportType
					AND cs.MaxTurnover <> t.MaxTurnover)					
	BEGIN		
		RETURN	
	END

	UPDATE t
	SET t.MaxTurnover_Old = cs.MaxTurnover
	FROM @tmpSetting t
		INNER JOIN TOControl_LeagueGroupSetting cs WITH (NOLOCK) ON t.ProfileID = cs.ProfileID
	WHERE cs.LeagueGroupID = @LeagueGroupID 
		AND cs.Market = @Market 
		AND cs.SportType = @SportType

	UPDATE cs
	SET cs.MaxTurnover = t.MaxTurnover
	FROM TOControl_LeagueGroupSetting cs WITH(ROWLOCK)
		INNER JOIN @tmpSetting t ON cs.ProfileID = t.ProfileID
	WHERE cs.LeagueGroupID = @LeagueGroupID 
		AND cs.Market = @Market 
		AND cs.SportType = @SportType

	IF @@ERROR > 0 
	BEGIN
		SELECT @ErrCode = 103, @ErrMsg = 'Edit League Group '+ @LeagueGroup +' unsuccessfully!'
		RETURN;		
	END

	INSERT INTO #tblCust (CustID, IsGroupHeadLine)
	SELECT DISTINCT cs.CustID, cs.IsGroupHeadLine
	FROM TOControl_GlobalSetting cs WITH (NOLOCK)
		INNER JOIN Customer c WITH(NOLOCK) ON cs.CustID = c.CustID
	WHERE cs.SportType = @SportType 
		AND cs.LeagueGroupID = @LeagueGroupID
		AND c.site IN (SELECT site FROM dbo.f_TOControl_GetSiteByMarket(@Market))
		AND cs.IsLeagueGroupLock = 0


	WHILE(1=1)
	BEGIN
		UPDATE TOP (1000) t
		SET t.isFinished = 1
		OUTPUT DELETED.CustID, DELETED.IsGroupHeadLine INTO @tmpCust(CustID, IsGroupHeadLine)
		FROM #tblCust t		
		WHERE t.isFinished = 0

		IF @@ROWCOUNT = 0 BREAK;

		UPDATE cs
		SET cs.MaxTurnOver = s.MaxTurnover,
			cs.RepUpdateTime = dbo.f_GetDateTime2()
		FROM TOControl_GlobalSetting cs WITH(ROWLOCK)
			INNER JOIN @tmpCust tc ON cs.CustID = tc.CustID AND cs.IsGroupHeadLine = tc.IsGroupHeadLine
			INNER JOIN @tmpSetting s ON cs.ProfileID = s.ProfileID
		WHERE cs.LeagueGroupID = @LeagueGroupID 
			AND cs.SportType = @SportType
			AND cs.IsLeagueGroupLock = 0
			
		DELETE @tmpCust
	END

	SET @MaxTurnover_Log = (
						SELECT STUFF((SELECT ',' + CAST(pf.ProfileName AS VARCHAR(50)) + '="' + CAST(m.MaxTurnover AS VARCHAR(50)) + '"'
						FROM @tmpSetting m
							INNER JOIN dbo.TOControl_Profile pf WITH (NOLOCK) ON m.ProfileID = pf.ProfileID
						FOR XML PATH('')),1,1,'')
					)
	SELECT @MaxTurnover_Log = REPLACE(REPLACE(REPLACE(@MaxTurnover_Log , '&amp;',''), ' ', ''), ',', ' ')

	SET @MaxTurnoverOld_Log = (
						SELECT STUFF((SELECT ',' + CAST(pf.ProfileName AS VARCHAR(50)) + '="' + CAST(m.MaxTurnover_Old AS VARCHAR(50)) + '"'
						FROM @tmpSetting m
							INNER JOIN dbo.TOControl_Profile pf WITH (NOLOCK) ON m.ProfileID = pf.ProfileID
						FOR XML PATH('')),1,1,'')
					)
	SELECT @MaxTurnoverOld_Log = REPLACE(REPLACE(REPLACE(@MaxTurnoverOld_Log , '&amp;',''), ' ', ''), ',', ' ')

	DECLARE @LogData NVARCHAR(4000),
			@LogData_Old NVARCHAR(4000)

	SELECT @LogData = '<NAP_TOControl_GlobalLeagueGroupSettingUpd Market="' + COALESCE(CAST(@Market as varchar(50)),space(1)) + '" ' 					
					+ 'LeagueGroup="' + COALESCE(CAST(@LeagueGroup AS VARCHAR(200)), SPACE(1)) + '" ' 
					+ 'SportType="' + COALESCE(CAST(@SportType AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ COALESCE(CAST(@MaxTurnover_Log AS VARCHAR(MAX)), SPACE(1)) + ' ' 				
					+ 'IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1)) + '" '
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" />'

	SELECT @LogData_Old = '<NAP_TOControl_GlobalLeagueGroupSettingUpd Market="' + COALESCE(CAST(@Market as varchar(50)),space(1)) + '" ' 					
					+ 'LeagueGroup="' + COALESCE(CAST(@LeagueGroup AS VARCHAR(200)), SPACE(1)) + '" ' 
					+ 'SportType="' + COALESCE(CAST(@SportType AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ COALESCE(CAST(@MaxTurnoverOld_Log AS VARCHAR(MAX)), SPACE(1)) + ' ' 				
					+ 'IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1)) + '" '
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" />'

	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)

	-- WRITE LOG
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@Userid = @UserID,
					@CustID = @LeagueGroupID,
					@ActionID = 95128,
					@TrackingValue = @LogData,
					@TrackingValue2 = @LogData_Old,
					@Duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @Remark = 'ErrMsg=' + LEFT(ERROR_MESSAGE(), 350)

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@Userid = @UserID,
					@CustID = @LeagueGroupID,
					@ActionID = 95128,
					@TrackingValue = @LogData,
					@Duration = @duration,
					@Doing = @Remark
	END CATCH
END