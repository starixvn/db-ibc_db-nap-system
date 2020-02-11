/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_GlobalSettingInsert]
	@UserName NVARCHAR(30),
	@GlobalSetting VARCHAR(MAX) = '',
	@IsGroupHeadline BIT = 0,
	@SportType SMALLINT = 1,
	@UserID INT,
	@IP	VARCHAR(40),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(200) = '' OUTPUT
AS

/*
	Created: Don
	Date: 2017-03-24
	Task: Insert new CustId to Gobal setting
	DB: DBCUST.CustDB

	Revisions:
		- 20170920@Helen: TO Control Phase 3 - [Redmine: 75557]
		- 20171115@Vicky: change location check permission [RedmineID: #86455]
		- 20171212@Helen: Implement some change request from OPS Team - [Redmine: 85638]
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
		- 20190927@Helen: Differentiate alert thresholds between MBC and CN88 [Redmine: #119561]
		- 20200102@Malcolm: Separate setting and notification into Live/Non-Live and bettypes - [Redmine: #126348]
		- 20200122@Max: Support Separate setting and notification into Live/Non-Live major and minor bettypes [Redmine: #126841]
		
	Parameter's explaination:
		Sample data for @GlobalSetting: 
			'<ROOT>
				<GlobalSetting MaxTurnover="100" ProfileID  = "1" />
				<GlobalSetting MaxTurnover="1" ProfileID  = "1"/>
			</ROOT>'
*/
BEGIN 
	SET NOCOUNT ON

	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT,
			@FunctionKey NVARCHAR(50)
			
	DECLARE @roleid INT, @iDoc INT
	SET	@startRun = GETDATE()
	
	IF @SportType = 1 
		SET @FunctionKey = 'GlobalSetting_Soccer'
	ELSE
		SET @FunctionKey = 'GlobalSetting_OtherSports'
	
	
	--Check permission 
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission @UserId=@UserID,@SiteKey='CustomerManagement',@FunctionKey=@FunctionKey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	
	DECLARE @CustID INT, @GroupHeadlineID INT
	DECLARE @MaxLevel TINYINT
	
	SELECT @CustID = CustID, @roleid = RoleID FROM dbo.CustInfo WITH(NOLOCK) WHERE UserName = @UserName

	IF (@CustID IS NULL OR @roleid = 1) AND @IsGroupHeadline = 0
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Invalid Super/Master/Agent.'
		RETURN
	END
	
	IF @IsGroupHeadline = 1
	BEGIN
		SET @GroupHeadlineID = (SELECT GroupID FROM dbo.CustGroupHeadline CG WITH (NOLOCK) WHERE CustID = @CustID)
		
		IF @GroupHeadlineID IS NULL
		BEGIN
			SELECT @ErrCode = 101, @ErrMsg = 'Invalid Headline.'
			RETURN
		END	
	END
	
	IF EXISTS (SELECT 1 FROM dbo.TOControl_GlobalSetting WITH(NOLOCK) WHERE CustID = @CustID AND IsGroupHeadLine = @IsGroupHeadline AND Sporttype = @SportType)
	BEGIN
			SELECT @ErrCode = 102, @ErrMsg = 'The setting of this customer already existed!'
			RETURN
	END
			
	SET @MaxLevel = (SELECT TOP 1 PercentLevel FROM dbo.TOControl_LevelSetting WITH (NOLOCK) WHERE PercentValue = 100)

	--#tmpMaxTurnover
	CREATE TABLE #tmpMaxTurnover(ProfileID SMALLINT, MaxTurnover MONEY)

	EXEC sp_xml_preparedocument @iDoc OUTPUT, @GlobalSetting
	INSERT INTO #tmpMaxTurnover(MaxTurnover, ProfileID)
	SELECT MaxTurnover, ProfileID 
	FROM OPENXML(@iDoc, '/ROOT/GlobalSetting', 1) WITH (MaxTurnover MONEY, ProfileID SMALLINT)
	EXEC sp_xml_removedocument @iDoc
	
	CREATE TABLE #tmpTurnover(MatchId INT, bettype SMALLINT, liveindicator bit, SumOfStake MONEY, HouseTurnover MONEY)
	
	INSERT INTO #tmpTurnover(MatchId, bettype, liveindicator, SumOfStake, HouseTurnover)
	EXECUTE DBAGE.bodb02.dbo.NAP_TOControl_MatchTurnoverByCustomerSelect @CustID = @CustID, @RoleID = @roleid, @IsGroupHeadline = @IsGroupHeadline, @SportType = @SportType
	
	
	INSERT INTO dbo.TOControl_Setting(CustID, matchid, MaxTurnOver, TotalTurnOver, HouseTurnover, PercentLevel, IsNotified,IsGroupHeadline, ProfileID)
	SELECT
		@CustID, t.MatchId, m.MaxTurnover AS MaxTurnOver, t.SumOfStake AS TotalTurnOver, t.HouseTurnover
		,	CASE	WHEN m.MaxTurnover = 0 THEN @MaxLevel 
					ELSE ISNULL((SELECT MAX(PercentLevel) FROM dbo.TOControl_LevelSetting (NOLOCK) WHERE ((HouseTurnover*100)/m.MaxTurnover) >= PercentValue),0)
			END AS PercentLevel
			
		, 0 AS IsNotified
		, @IsGroupHeadline AS IsGroupHeadline
		, m.ProfileID
	FROM #tmpMaxTurnover m WITH (NOLOCK)
		INNER JOIN (
						SELECT pf.ProfileID, t_tmp. MatchId, SUM(t_tmp.SumOfStake) AS SumOfStake, SUM(t_tmp. HouseTurnover) AS HouseTurnover
						FROM #tmpTurnover t_tmp
							INNER JOIN DBCUST.CUSTDB.dbo.TOControl_ProfileSetting pf ON  pf.Sporttype = @SportType 
											AND t_tmp.liveindicator = pf.liveindicator 
											AND (t_tmp.bettype = pf.Bettype 
													OR ( NOT EXISTS ( SELECT 1 
																		FROM TOControl_ProfileSetting p WITH (NOLOCK)
																		WHERE p.Sporttype = @SportType 
																			AND p.Bettype = t_tmp.bettype 
																			AND p.liveindicator = t_tmp.liveindicator
																	)
														AND pf.Bettype = 0
													))
						GROUP BY t_tmp.MatchId, pf.ProfileID
					) t ON m.ProfileID = t.ProfileID
		
	IF @@ERROR > 0 
	BEGIN
		SELECT @ErrCode = 103, @ErrMsg = 'Adding failed.'
		RETURN;
		
	END
	
	INSERT INTO dbo.TOControl_GlobalSetting(CustID, ProfileID, MaxTurnOver,SportType,IsGroupHeadLine) 
	SELECT @CustID, m.ProfileID, m.MaxTurnover,@SportType, @IsGroupHeadline
	FROM #tmpMaxTurnover m WITH (NOLOCK)


	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond, @startRun, @endRun)

	DECLARE @LogData NVARCHAR(4000)
	SELECT @LogData = '<NAP_TOControl_GlobalSettingInsert CustID="' + COALESCE(CAST(@CustID as varchar(50)),space(1)) + '" ' 					
					+ 'SportType="' + COALESCE(CAST(@SportType AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'MaxTuronver="' + COALESCE(CAST(@GlobalSetting AS VARCHAR(MAX)), SPACE(1)) + '" ' 
					+ 'IsGroupHeadline="' + COALESCE(CAST(@IsGroupHeadline AS VARCHAR(50)), SPACE(1)) + '" ' 
					+ 'IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1)) + '" '
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" />'
														
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)

	-- WRITE LOG
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@Userid = @UserID,
				@CustID = @CustID,
				@ActionID = 668,
				@TrackingValue = @LogData,
				@Duration = @duration

END
GO


