/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_Customer_MonitorPT_Upd]
	@custidList VARCHAR(max),
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
	
	DECLARE @tmpCust TABLE (custid INT, isMonitorPT_Old BIT, isLog BIT DEFAULT 0)
	
	INSERT INTO @tmpCust(custid)
	SELECT val
	FROM dbo.strSplit(@custidList,',')
		
	UPDATE t
	SET isMonitorPT_Old = ISNULL(c.isMonitorPT,0)
	FROM @tmpCust t 
		INNER JOIN custAgent c WITH(NOLOCK) ON t.custid = c.custid		
	
	DELETE @tmpCust WHERE isMonitorPT_Old IS NULL
	
	IF NOT EXISTS(SELECT top(1) 1 FROM @tmpCust WHERE isMonitorPT_old <> @isMonitorPT)
		RETURN;
		
	UPDATE custAgent WITH(UPDLOCK,ROWLOCK)
	SET isMonitorPT = @isMonitorPT
	WHERE custid IN (SELECT custid FROM @tmpCust WHERE isMonitorPT_old <> @isMonitorPT)
	
	IF @@ERROR > 0
	BEGIN
		SELECT @ErrCode = 101,
				@ErrMsg = 'Update unsuccessfully.'
		RETURN;
	END
	
	DECLARE @LogData NVARCHAR(4000),	
			@LogData_Old NVARCHAR(4000),
			@isMonitorPT_Old BIT,
			@custid INT
			
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	
	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) @tmpCust
		SET isLog = 1,
			@isMonitorPT_Old = isMonitorPT_Old,
			@custid = custid
		WHERE isLog = 0 
			AND isMonitorPT_Old <> @isMonitorPT
		
		IF @@rowcount = 0 BREAK;
		
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
END
GO