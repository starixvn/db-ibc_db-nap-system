/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_GlobalSettingLockTOLimit_Update]
(
	@CustID INT,
	@IsGlobalLockTOLimit BIT,
	@SportType SMALLINT = 1,
	@IsGroupHeadLine BIT = 0,
	@UserID INT,
	@IP	VARCHAR(40),
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
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
		- 20241225@July: Scale out DB - In-house Replicator - Support change for SMA TO Control [Redmine: #207042]
		
	Parameter's explaination:
	 
*/

BEGIN 
	SET NOCOUNT ON
	
	DECLARE @IsGlobalLockTOLimit_Old BIT
	
	DECLARE @startRun	DATETIME,
		@endRun		DATETIME,
		@duration	INT,
		@FunctionKey NVARCHAR(50),
		@Remark		VARCHAR(500)
			
	SET	@startRun = GETDATE()

	IF @SportType = 1 
		SET @FunctionKey = 'GlobalSetting_Soccer'
	ELSE
		SET @FunctionKey = 'GlobalSetting_OtherSports'
	
		
	--Check permission 
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission @UserId=@UserID,@SiteKey='CustomerManagement',@FunctionKey=@FunctionKey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	

	SET @IsGlobalLockTOLimit_Old = ( SELECT DISTINCT ISNULL(t.IsGlobalLockTOLimit,0)
										FROM dbo.TOControl_GlobalSetting t WITH(NOLOCK)
										WHERE t.CustID = @CustID AND t.IsGroupHeadLine= @IsGroupHeadLine AND Sporttype = @SportType
									)
	IF @CustID <= 0
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Invalid Super/Master/Agent.'
		RETURN
	END

	UPDATE dbo.TOControl_GlobalSetting WITH(ROWLOCK, UPDLOCK) 
	SET IsGlobalLockTOLimit = @IsGlobalLockTOLimit
	  , RepUpdateTime = dbo.f_GetDateTime2()
	WHERE CustID = @CustID AND Sporttype = @SportType AND IsGroupHeadLine= @IsGroupHeadLine
	
	UPDATE t
		SET 
			t.IsGlobalLockTOLimit = @IsGlobalLockTOLimit	
			,t.ModifiedDate = GETDATE()
	FROM dbo.TOControl_Setting t WITH(ROWLOCK, UPDLOCK)
	WHERE t.CustID = @CustID AND IsGroupHeadLine = @IsGroupHeadLine

	DECLARE @LogData NVARCHAR(4000), @TrackingValue2 NVARCHAR(4000)

	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	

	SELECT @LogData = '<NAP_TOControl_GlobalSettingLockTOLimit_Update CustID="' + COALESCE(CAST(@CustID AS VARCHAR(10)), SPACE(1)) + '" ' 					
					+ 'SportType="' + COALESCE(CAST(@SportType AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'GlobalLock="' + COALESCE(CAST(@IsGlobalLockTOLimit AS VARCHAR(20)), SPACE(1)) + '" '  
					+ 'IsGroupHeadline="' + COALESCE(CAST(@IsGroupHeadline AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1)) + '" '
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" />'
	-- For old value
	SELECT @TrackingValue2 = '<NAP_TOControl_GlobalSettingLockTOLimit_Update CustID="' + COALESCE(CAST(@CustID AS VARCHAR(10)), SPACE(1)) + '" ' 					
					+ 'SportType="' + COALESCE(CAST(@SportType AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'GlobalLock="' + COALESCE(CAST(@IsGlobalLockTOLimit_Old AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'IsGroupHeadline="' + COALESCE(CAST(@IsGroupHeadline AS VARCHAR(20)), SPACE(1)) + '" ' 
					+ 'IP="'+ COALESCE(CAST(@IP as varchar(15)),space(1)) + '" '
					+ 'ErrCode="'+ COALESCE(CAST(@ErrCode as varchar(50)),space(1)) + '" '
					+ 'ErrMsg="'+ COALESCE(CAST(@ErrMsg as varchar(200)),space(1)) + '" />'
	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@Userid = @UserID,
					@CustID = @CustID,
					@ActionID = 761,
					@TrackingValue = @LogData,
					@TrackingValue2 = @TrackingValue2,
					@Duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @Remark = 'ErrMsg=' + LEFT(ERROR_MESSAGE(), 350)

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
					@Userid = @UserID,
					@CustID = @CustID,
					@ActionID = 761,
					@TrackingValue = @LogData,
					@TrackingValue2 = @TrackingValue2,
					@Duration = @duration,
					@Doing = @Remark
	END CATCH
			
END
GO