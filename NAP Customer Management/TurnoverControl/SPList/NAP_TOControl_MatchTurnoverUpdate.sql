/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_MatchTurnoverUpdate]
	@CustID INT,
	@MatchID INT,
	@SportType SMALLINT = 1,
	@IsGroupHeadline BIT = 0,
	@MaxTurnover MONEY,
	@ProfileID SMALLINT,
	@UserID INT,
	@IP	VARCHAR(40),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
	Created: Don
	Date: 2017-03-23
	Task: Update MaxTurnover for Super/Master/Agent
	DB: DBCUST/CustDB

	Revisions:
		- 20170920@Helen: TO Control Phase 3 - [Redmine: 75557]
		- 20171115@Vicky: change location check permission [RedmineID: #86455]
		- 20171212@Helen: Implement some change request from OPS Team - [Redmine: 85638]
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
		- 20190927@Helen: Differentiate alert thresholds between MBC and CN88 [Redmine: #119561]
		- 20190102@Malcolm: Separate setting and notification into Live/Non-Live and bettypes [Redmine : 125076]
		
	Parameter's explaination:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @LogData			NVARCHAR(4000),
			@TrackingValue2		NVARCHAR(4000),
			@startRun			DATETIME,
			@endRun				DATETIME,
			@duration			INT,
			@MaxTurnover_old	MONEY,
			@FunctionKey		NVARCHAR(50),
			@ProfileName		VARCHAR(50)
	
	DECLARE @SiteID INT
	
	SET	@startRun = GETDATE()

	IF @SportType = 1 
		SET @FunctionKey = 'TurnoverMonitor_Soccer'
	ELSE
		SET @FunctionKey = 'TurnoverMonitor_OtherSports'
		
	
	--Check permission 
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission @UserId=@UserID,@SiteKey='CustomerManagement',@FunctionKey=@FunctionKey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	
	IF EXISTS (SELECT 1 FROM DBAGE.bodb02.dbo.match WITH (NOLOCK) WHERE matchid = @MatchID AND eventstatus = 'completed')
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'You are not allowed to update max turnover of a settled match.'
		RETURN
	END

	SELECT @MaxTurnover_old = t.MaxTurnover
		 , @ProfileName = pf.ProfileName
	FROM dbo.TOControl_Setting t WITH (NOLOCK)
		INNER JOIN dbo.TOControl_Profile pf WITH (NOLOCK) ON t.ProfileID = pf.ProfileID
	WHERE CustID = @CustID AND matchid = @MatchID AND IsGroupHeadLine = @IsGroupHeadline AND t.ProfileID = @ProfileID
	
	SET @SiteID = (SELECT TOP 1 s.siteid
					FROM dbo.Customer c WITH (NOLOCK) 
						INNER JOIN dbo.Site s WITH (NOLOCK) ON c.site = s.site
					WHERE custid = @CustID
					)
	
	SET @siteID = ISNULL((SELECT TOP 1 SiteID FROM dbo.TOControl_LevelSetting (NOLOCK) WHERE SiteID = @SiteID),0)
	
	IF @MaxTurnover = 0
	BEGIN
		UPDATE dbo.TOControl_Setting WITH(ROWLOCK, UPDLOCK)
		SET 
			MaxTurnover = @MaxTurnover,
			IsNotified = 0
		WHERE CustID = @CustID AND matchid = @MatchID AND IsGroupHeadLine = @IsGroupHeadline AND ProfileID = @ProfileID
	END
	ELSE
	BEGIN
		UPDATE dbo.TOControl_Setting WITH(ROWLOCK, UPDLOCK)
			SET 
				MaxTurnover = @MaxTurnover,
				IsNotified =  ISNULL((SELECT MAX(PercentValue) 
										FROM dbo.TOControl_LevelSetting WITH(NOLOCK) 
										WHERE (HouseTurnOver*100/@MaxTurnover) >= PercentValue AND IsNotified = 1
											AND SiteID = @SiteID
									),0),
				PercentLevel = ISNULL((SELECT MAX(PercentLevel) 
										FROM dbo.TOControl_LevelSetting WITH (NOLOCK) 
										WHERE (HouseTurnOver*100/@MaxTurnover) >= PercentValue
										),0) 
						
		WHERE CustID = @CustID AND matchid = @MatchID AND IsGroupHeadLine = @IsGroupHeadline AND ProfileID = @ProfileID
		
	END

	SELECT @ProfileName = REPLACE(REPLACE(REPLACE(@ProfileName , '&',''), ' ', ''), ',', ' ')

	SELECT @LogData = '<NAP_TOControl_MatchTurnoverUpdate CustID="' + COALESCE(CAST(@CustID AS VARCHAR(10)), SPACE(1)) + '" ' 					
					+ 'SportType="' + COALESCE(CAST(@SportType AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'IsGroupHeadline="' + COALESCE(CAST(@IsGroupHeadline AS VARCHAR(10)), SPACE(1)) + '" ' 
					+ 'MatchID="' + COALESCE(CAST(@MatchID AS VARCHAR(10)), SPACE(1)) + '" ' 
					+ @ProfileName + '="' + COALESCE(CAST(@MaxTurnover AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" '
					+ 'IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1))+ '" />'
							
	-- For Old value
	SELECT @TrackingValue2 = '<NAP_TOControl_MatchTurnoverUpdate CustID="' + COALESCE(CAST(@CustID AS VARCHAR(10)), SPACE(1)) + '" ' 					
					+ 'SportType="' + COALESCE(CAST(@SportType AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'IsGroupHeadline="' + COALESCE(CAST(@IsGroupHeadline AS VARCHAR(10)), SPACE(1)) + '" ' 
					+ 'MatchID="' + COALESCE(CAST(@MatchID AS VARCHAR(10)), SPACE(1)) + '" ' 
					+ @ProfileName + '="' + COALESCE(CAST(@MaxTurnover_old AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" '
					+ 'IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1))+ '" />'
					
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	
	
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
		@Userid = @UserID,
		@Custid = @CustID,
		@ActionID = 671,
		@TrackingValue = @LogData,
		@TrackingValue2 = @TrackingValue2,
		@Duration = @duration					
						
END
GO

