/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_TOControl_MatchTurnoverLockTOLimit_Update]
(
	@CustID INT,
	@MatchID INT,
	@SportType SMALLINT = 1,
	@IsEventLockTOLimit BIT,
	@IsGroupHeadline BIT = 0,
	@UserID INT,
	@IP	VARCHAR(40),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
	Created: Max
	Date: 2020-07-14
	Task: SMA TO Control - Add block increasing TO Limit feature to specific SMAs - [Redmine: #136254]
	DB: DBCUST.CustDB

	Revisions:
		- 20200714@Max: SMA TO Control - Add block increasing TO Limit feature to specific SMAs - [Redmine: #136254]
		- 20231127@Max: Apply try catch when write log [Redmine: #197464]
		
	Parameter's explaination:
	 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @LogData			NVARCHAR(4000),
			@TrackingValue2		NVARCHAR(4000),
			@startRun			DATETIME,
			@endRun				DATETIME,
			@duration			INT,
			@IsEventLockTOLimit_Old	BIT,
			@FunctionKey		NVARCHAR(50),
			@ProfileName		VARCHAR(50),
			@Remark				VARCHAR(500)
	
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

	SELECT @IsEventLockTOLimit_Old = t.IsEventLockTOLimit
	FROM dbo.TOControl_Setting t WITH (NOLOCK)
	WHERE CustID = @CustID AND matchid = @MatchID AND IsGroupHeadLine = @IsGroupHeadline
	
	UPDATE dbo.TOControl_Setting WITH(ROWLOCK, UPDLOCK)
	SET 
		IsEventLockTOLimit = @IsEventLockTOLimit
	WHERE CustID = @CustID AND matchid = @MatchID AND IsGroupHeadLine = @IsGroupHeadline
	

	SELECT @ProfileName = REPLACE(REPLACE(REPLACE(@ProfileName , '&',''), ' ', ''), ',', ' ')

	SELECT @LogData = '<NAP_TOControl_MatchTurnoverLockTOLimit_Update CustID="' + COALESCE(CAST(@CustID AS VARCHAR(10)), SPACE(1)) + '" ' 					
					+ 'SportType="' + COALESCE(CAST(@SportType AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'MatchID="' + COALESCE(CAST(@MatchID AS VARCHAR(10)), SPACE(1)) + '" ' 
					+ 'EventLock="' + COALESCE(CAST(@IsEventLockTOLimit AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'IsGroupHeadline="' + COALESCE(CAST(@IsGroupHeadline AS VARCHAR(10)), SPACE(1)) + '" ' 
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" '
					+ 'IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1))+ '" />'
							
	-- For Old value
	SELECT @TrackingValue2 = '<NAP_TOControl_MatchTurnoverLockTOLimit_Update CustID="' + COALESCE(CAST(@CustID AS VARCHAR(10)), SPACE(1)) + '" ' 					
					+ 'SportType="' + COALESCE(CAST(@SportType AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'MatchID="' + COALESCE(CAST(@MatchID AS VARCHAR(10)), SPACE(1)) + '" ' 
					+ 'EventLock="' + COALESCE(CAST(@IsEventLockTOLimit_Old AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'IsGroupHeadline="' + COALESCE(CAST(@IsGroupHeadline AS VARCHAR(10)), SPACE(1)) + '" ' 
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" '
					+ 'IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1))+ '" />'
					
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@Userid = @UserID,
			@Custid = @CustID,
			@ActionID = 762,
			@TrackingValue = @LogData,
			@TrackingValue2 = @TrackingValue2,
			@Duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @Remark = 'ErrMsg=' + LEFT(ERROR_MESSAGE(), 350)

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@Userid = @UserID,
			@Custid = @CustID,
			@ActionID = 762,
			@TrackingValue = @LogData,
			@TrackingValue2 = @TrackingValue2,
			@Duration = @duration,
			@Doing = @Remark
	END CATCH
						
END
GO

