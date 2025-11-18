/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_GlobalLeagueGroupDel]
    @LeagueGroups VARCHAR(MAX),   
	@SportType SMALLINT = 1,
	@UserID INT,
	@IP	VARCHAR(40),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
	Created: 20251120@Johnson	
	Task: Delete global league group setting
	DB: DBCUST.CustDB

	Revisions:
		- 20251120@Johnson: TO Monitor Control By League Group [Redmine: 243977]

	Parameter's explaination:		
		@Market: 1: Malay, 2: 789y, 3: others	
		@LeagueGroups: 
			'<ROOT>
				<r ID="0" LeagueGroup = "None" Market="1"/>
				<r ID="1" LeagueGroup = "Major League" Market="2"/>
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
			
	DECLARE @tmpLeagueGroup TABLE (LeagueGroupID INT PRIMARY KEY, LeagueGroup VARCHAR(200), Market TINYINT)
	DECLARE @MatchList TABLE(matchid INT, LeagueGroupID INT)	
	CREATE TABLE #tblCust (CustID INT , IsGroupHeadLine BIT, LeagueGroupID INT, isFinished BIT DEFAULT (0) PRIMARY KEY(CustID, IsGroupHeadLine, LeagueGroupID))	
	DECLARE @tmpCust TABLE (CustID INT, IsGroupHeadLine BIT, LeagueGroupID INT PRIMARY KEY(CustID, IsGroupHeadLine, LeagueGroupID))

	SET	@startRun = GETDATE()
	
	IF @SportType = 1 
		SET @FunctionKey = 'GlobalLeagueGroupSetting_Soccer'

	--Check permission 
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission @UserId=@UserID,@SiteKey='CustomerManagement',@FunctionKey=@FunctionKey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN	

	INSERT INTO @tmpLeagueGroup (LeagueGroupID,LeagueGroup,Market)
	SELECT 
		T.c.value('@ID', 'INT') AS LeagueGroupID,
		T.c.value('@LeagueGroup', 'VARCHAR(200)') AS LeagueGroup,
		T.c.value('@Market', 'TINYINT') AS Market
	FROM 
		(SELECT CAST(@LeagueGroups AS XML) AS LeagueGroupsXML) AS A
	CROSS APPLY 
		LeagueGroupsXML.nodes('/ROOT/r') AS T(c)

	INSERT INTO @MatchList(matchid, LeagueGroupID)
	SELECT m.matchid, m.homeid, m.awayid, m.eventdate, m.sporttype, m.leagueid
	FROM DBAGE.bodb02.dbo.match m WITH(NOLOCK)
		INNER JOIN DBAGE.bodb02.dbo.league lg WITH(NOLOCK) ON m.leagueid = lg.leagueid
	WHERE m.eventstatus <> 'completed'
		AND (@SportType = 1 AND sporttype = 1) 

	DELETE @matchList
	WHERE LeagueGroupID NOT IN (SELECT LeagueGroupID FROM @tmpLeagueGroup)

	INSERT INTO #tblCust (CustID, IsGroupHeadLine, LeagueGroupID)
	SELECT DISTINCT cs.CustID, cs.IsGroupHeadLine, cs.LeagueGroupID
	FROM TOControl_GlobalSetting cs WITH (NOLOCK)
		INNER JOIN Customer c WITH(NOLOCK) ON cs.CustID = c.CustID
		INNER JOIN @tmpLeagueGroup lg ON cs.LeagueGroupID = lg.LeagueGroupID
	WHERE cs.SportType = @SportType 		
		AND c.site IN (SELECT site FROM dbo.f_TOControl_GetSiteByMarket(lg.Market))

	DELETE cs
	FROM dbo.TOControl_LeagueGroupSetting cs WITH(ROWLOCK) 
		INNER JOIN @tmpLeagueGroup lg ON cs.LeagueGroupID = lg.LeagueGroupID AND lg.Market = cs.Market
	WHERE SportType = @SportType
			
	WHILE(1=1)
	BEGIN
		UPDATE TOP (500) t
		SET t.isFinished = 1
		OUTPUT DELETED.CustID, DELETED.IsGroupHeadLine, DELETED.LeagueGroupID 
		INTO @tmpCust(CustID, IsGroupHeadLine, LeagueGroupID)
		FROM #tblCust t		
		WHERE t.isFinished = 0

		IF @@ROWCOUNT = 0 BREAK;

		DELETE cs
		OUTPUT DELETED.CustID, DELETED.SportType, DELETED.IsGroupHeadLine, DELETED.ProfileID, DELETED.ID,dbo.f_GetDateTime2()
		INTO dbo.TOControl_GlobalSetting_Del_Inhouse(CustID, SportType, IsGroupHeadLine, ProfileID, ID, RepUpdateTime)
		FROM TOControl_GlobalSetting cs WITH(ROWLOCK) 
			INNER JOIN @tmpCust t ON cs.CustID = t.CustID AND cs.IsGroupHeadLine = t.IsGroupHeadLine AND cs.LeagueGroupID = t.LeagueGroupID
		WHERE cs.SportType = @SportType

		DELETE @tmpCust
	END

	WHILE(1=1)
	BEGIN
		DELETE TOP (5000) cs
		FROM dbo.TOControl_Setting cs WITH(ROWLOCK, UPDLOCK)			
			INNER JOIN #tblCust t ON cs.CustID = t.CustID AND cs.IsGroupHeadLine = t.IsGroupHeadLine
			INNER JOIN @MatchList m ON m.matchid = cs.matchid AND m.LeagueGroupID = t.LeagueGroupID
		WHERE NOT EXISTS (SELECT 1 
						FROM TOControl_GlobalSetting gs WITH (NOLOCK)
						WHERE gs.CustID = cs.CustID 
							AND gs.IsGroupHeadLine = cs.IsGroupHeadLine
							AND gs.SportType = @SportType
							AND gs.LeagueGroupID = -1-- dont have League Group Default
						)
		
		IF @@ROWCOUNT = 0 BREAK;
	END

	SELECT @LeagueGroup_Log = CAST((
	SELECT 		
		lg.LeagueGroup AS [@LeagueGroup], 
		lg.Market AS [@Market]
	FROM @tmpLeagueGroup lg
	FOR XML PATH('r'), TYPE
	)AS VARCHAR(MAX))

	DECLARE @LogData NVARCHAR(MAX)
	SELECT @LogData = '<NAP_TOControl_GlobalLeagueGroupSettingDel IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1)) + '" '
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" >'
					+ COALESCE(CAST(@LeagueGroup_Log AS VARCHAR(MAX)), SPACE(1)) 
					+ ' </NAP_TOControl_GlobalLeagueGroupSettingDel>'
														
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)

	-- WRITE LOG
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@Userid = @UserID,					
					@ActionID = 95129,
					@TrackingValue = @LogData,
					@Duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @Remark = 'ErrMsg=' + LEFT(ERROR_MESSAGE(), 350)

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@Userid = @UserID,					
					@ActionID = 95129,
					@TrackingValue = @LogData,
					@Duration = @duration,
					@Doing = @Remark
	END CATCH
END