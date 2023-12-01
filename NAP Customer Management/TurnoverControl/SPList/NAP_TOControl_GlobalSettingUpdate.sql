/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_GlobalSettingUpdate]
(
	@CustID INT,
	@MaxTurnover MONEY,
	@ProfileID SMALLINT,
	@SportType SMALLINT = 1,
	@IsGroupHeadLine BIT = 0,
	@UserID INT,
	@IP	VARCHAR(40),
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
)
AS

/*
	Created: Don
	Date: 2017-03-27
	Task: Update CustId's turnover to Gobal setting
	DB: DBCUST.CustDB

	Revisions:
		- 20170920@Helen: TO Control Phase 3 - [Redmine: 75557]
		- 20171115@Vicky: change location check permission [RedmineID: #86455]
		- 20171212@Helen: Implement some change request from OPS Team - [Redmine: 85638]
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
		- 20190927@Helen: Differentiate alert thresholds between MBC and CN88 [Redmine: #119561]
		- 20200102@Malcolm: Separate setting and notification into Live/Non-Live and bettypes - [Redmine: #126348]
		- 20200714@Max: SMA TO Control - Add block increasing TO Limit feature to specific SMAs - [Redmine: #136254]
		- 20201223@Max: Hotfix - ToControl_Percentlevel is not updated if user place bet made house TO negative then add SMA to ToControl [Redmine: #147580]
		- 20231127@Max: Apply try catch when write log [Redmine: #197464]
		
	Parameter's explaination:
	 
*/

BEGIN 
	SET NOCOUNT ON

	DECLARE @MatchList TABLE(matchid INT, homeid INT, awayid INT, eventdate DATETIME, sporttype INT, leagueid INT)
	
	DECLARE @MaxTurnover_Old MONEY, @AffectedMatch VARCHAR(1000) = '', @ProfileName VARCHAR(50)
	DECLARE @PercentageUsed MONEY
	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT,
			@FunctionKey NVARCHAR(50),
			@Remark		VARCHAR(500)
	
	DECLARE @MaxLevel TINYINT	
			, @SiteID INT
			
	SET	@startRun = GETDATE()

	IF @SportType = 1 
		SET @FunctionKey = 'GlobalSetting_Soccer'
	ELSE
		SET @FunctionKey = 'GlobalSetting_OtherSports'
	
		
	--Check permission 
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission @UserId=@UserID,@SiteKey='CustomerManagement',@FunctionKey=@FunctionKey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	
			
	SET @MaxLevel = (SELECT TOP 1 PercentLevel FROM dbo.TOControl_LevelSetting WITH (NOLOCK) WHERE PercentValue = 100)
	
	SET @SiteID = (SELECT TOP 1 s.siteid
					FROM dbo.Customer c WITH (NOLOCK) 
						INNER JOIN dbo.Site s WITH (NOLOCK) ON c.site = s.site
					WHERE custid = @CustID
					)
	
	SET @siteID = ISNULL((SELECT TOP 1 SiteID FROM dbo.TOControl_LevelSetting (NOLOCK) WHERE SiteID = @SiteID),0)
		
	INSERT INTO @MatchList(matchid, homeid, awayid, eventdate, sporttype, leagueid)
	SELECT m.matchid, m.homeid, m.awayid, m.eventdate, m.sporttype, m.leagueid
	FROM DBAGE.bodb02.dbo.match m WITH(NOLOCK)
	WHERE m.eventstatus <> 'completed'
		AND (
				-- Soccer
				(@SportType = 1 AND m.sporttype = 1) 
				OR 
				-- Other sports
				(@SportType = 99 AND m.sporttype > 1 AND m.sporttype <=99 )
			 )

	SELECT @MaxTurnover_Old = t.MaxTurnover 
		, @ProfileName = pf.ProfileName
	FROM dbo.TOControl_GlobalSetting t WITH(NOLOCK)
		INNER JOIN dbo.TOControl_Profile pf WITH (NOLOCK) ON t.ProfileID = pf.ProfileID
	WHERE t.CustID = @CustID AND t.IsGroupHeadLine = @IsGroupHeadLine AND t.ProfileID = @ProfileID

	SELECT @AffectedMatch = @AffectedMatch + CAST(t.MatchID AS VARCHAR(20)) + ',' 
	FROM dbo.TOControl_Setting t WITH(NOLOCK) 
		INNER JOIN @MatchList m ON m.matchid = t.matchid
	WHERE t.CustID = @CustID AND t.IsGroupHeadLine = @IsGroupHeadLine AND t.ProfileID = @ProfileID

	IF (LEN(ISNULL(@AffectedMatch, '')) > 0)
	BEGIN
		SELECT @AffectedMatch = LEFT(@AffectedMatch, LEN(@AffectedMatch)-1)
	END

	IF @CustID <= 0
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Invalid Super/Master/Agent.'
		RETURN
	END

	IF @MaxTurnover < 0
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'Invalid MaxTurnover.'
		RETURN
	END

	UPDATE dbo.TOControl_GlobalSetting WITH(ROWLOCK, UPDLOCK) 
	SET MaxTurnOver = @MaxTurnover 
	WHERE CustID = @CustID AND Sporttype = @SportType AND IsGroupHeadLine = @IsGroupHeadLine AND ProfileID = @ProfileID
	
	UPDATE t
		SET 
			t.MaxTurnover = @MaxTurnover,
			t.IsNotified = 	CASE WHEN @MaxTurnover = 0 THEN @MaxLevel 
								  ELSE ISNULL((SELECT MAX(PercentValue) 
												FROM dbo.TOControl_LevelSetting WITH (NOLOCK) 
												WHERE ABS(t.HouseTurnOver*100/@MaxTurnover) >= PercentValue AND IsNotified = 1
													AND SiteID = @SiteID
												),0)
								END	,
			t.ModifiedDate = GETDATE()
	FROM dbo.TOControl_Setting t WITH(ROWLOCK, UPDLOCK)
		INNER JOIN @MatchList m ON m.matchid = t.matchid
	WHERE t.CustID = @CustID AND t.IsGroupHeadLine = @IsGroupHeadLine AND t.ProfileID = @ProfileID
		AND IsEventLockTOLimit = 0
		AND IsGlobalLockTOLimit = 0

	DECLARE @LogData NVARCHAR(4000), @TrackingValue2 NVARCHAR(4000)

	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	
	SELECT @ProfileName = REPLACE(REPLACE(REPLACE(@ProfileName , '&',''), ' ', ''), ',', ' ')

	SELECT @LogData = '<NAP_TOControl_GlobalSettingUpdate CustID="' + COALESCE(CAST(@CustID AS VARCHAR(10)), SPACE(1)) + '" ' 					
					+ 'SportType="' + COALESCE(CAST(@SportType AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ @ProfileName + '="' + COALESCE(CAST(@MaxTurnover AS VARCHAR(20)), SPACE(1)) + '" '  
					+ 'IsGroupHeadline="' + COALESCE(CAST(@IsGroupHeadline AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1)) + '" '
					+ 'AffectedMatch="' + COALESCE(@AffectedMatch,space(1)) + '" '
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" />'
	-- For old value
	SELECT @TrackingValue2 = '<NAP_TOControl_GlobalSettingUpdate CustID="' + COALESCE(CAST(@CustID AS VARCHAR(10)), SPACE(1)) + '" ' 					
					+ 'SportType="' + COALESCE(CAST(@SportType AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ @ProfileName + '="' + COALESCE(CAST(@MaxTurnover_Old AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'IsGroupHeadline="' + COALESCE(CAST(@IsGroupHeadline AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1)) + '" '
					+ 'AffectedMatch="' + COALESCE(@AffectedMatch,space(1)) + '" '
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" />'
	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@Userid = @UserID,
					@CustID = @CustID,
					@ActionID = 669,
					@TrackingValue = @LogData,
					@TrackingValue2 = @TrackingValue2,
					@Duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @Remark = 'ErrMsg=' + LEFT(ERROR_MESSAGE(), 350)

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@Userid = @UserID,
					@CustID = @CustID,
					@ActionID = 669,
					@TrackingValue = @LogData,
					@TrackingValue2 = @TrackingValue2,
					@Duration = @duration,
					@Doing = @Remark
	END CATCH
END
GO
GRANT EXECUTE ON [dbo].[NAP_TOControl_GlobalSettingUpdate] TO [bodbAdminNet]
GO