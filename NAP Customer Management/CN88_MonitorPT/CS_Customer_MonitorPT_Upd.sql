/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[CS_Customer_MonitorPT_Upd]
	@custid INT,
	@isMonitorPT BIT = 0,
	@userid INT,	
	@IP	VARCHAR(15)='',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(4000) = '' OUTPUT		
/*
		Created: Johnson
		Date: 2019-10-2
		Task: update monitor PT status for cn88		
		DB: DBCUST/CustDB
		
		Revision:
			- 20191002@Johnson: Initial sp [redmine:#117714]
		Parameter's Explanation:					
*/ 
AS
BEGIN
	SET NOCOUNT ON
		
	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT
	SET	@startRun = GETDATE()
	
	--Check permission
	EXEC DBCUST.NAP_UserControl.dbo.NAP_User_CheckPermission @UserId=@userid,@SiteKey='CustomerManagement',@FunctionKey='PossessStatistics_CN88',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	
	DECLARE @isMonitorPT_Old BIT
	
	SELECT @isMonitorPT_Old = ISNULL(isMonitorPT,0)
	FROM custAgent WITH(NOLOCK)
	WHERE custid = @custid
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 100,
				@ErrMsg = 'Invalid customer.'
		RETURN;
	END
	
	IF @isMonitorPT = @isMonitorPT_Old 
		RETURN;
	
	UPDATE custAgent WITH(UPDLOCK,ROWLOCK)
	SET isMonitorPT = @isMonitorPT
	WHERE custid = @custid
	
	IF @@ERROR > 0
	BEGIN
		SELECT @ErrCode = 101,
				@ErrMsg = 'Update unsuccessfully.'
		RETURN;
	END
	
	DECLARE @LogData NVARCHAR(4000),	
			@LogData_Old NVARCHAR(4000)
	
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	
	SELECT @LogData = '<R remark="' + COALESCE(CAST(@isMonitorPT as VARCHAR(10)),SPACE(1)) + '" '									
							+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
			,@LogData_Old = '<R remark="' + COALESCE(CAST(@isMonitorPT_Old as VARCHAR(10)),SPACE(1)) + '" '									
							+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'	
	
	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserID = @userid,
		@CustID = @CustID,
		@ActionID = 1171,
		@TrackingValue = @LogData,
		@TrackingValue2 = @LogData_Old,
		@duration = @duration
END
GO