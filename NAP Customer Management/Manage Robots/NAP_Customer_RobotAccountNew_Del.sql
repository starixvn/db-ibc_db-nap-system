/*<info serverAlias="DBONUSER-ON_USER" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_Customer_RobotAccountNew_Del]
	@custid INT,
	@userid INT,
	@IP	VARCHAR(15)='',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(4000) = '' OUTPUT	
AS
/*
		Created: Johnson
		Date: 2019-09-13
		Task: delete robot account new version
		DB: DBONUSER/ON_USER
		
		Revision:
			- 20190913@Johnson: Initial sp [redmine:#119714]
		Parameter's Explanation:			
*/ 
BEGIN
	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT
	SET	@startRun = GETDATE()
	
		--Check permission
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission @UserId=@userid,@SiteKey='CustomerManagement',@FunctionKey='ManageRobots',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	
	IF NOT EXISTS (SELECT top (1) 1 FROM RobotUsers WHERE custid = @custid)
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Invalid account.'
		RETURN
	END
	
	DELETE RobotUsers with (ROWLOCK) 
	OUTPUT getdate(), deleted.custid, deleted.[IP], deleted.LastChangeTime, deleted.[site], deleted.[counter], deleted.[serverip], deleted.[RobotDate], deleted.remark, deleted.AddedBy 
	INTO RobotUsers_DelLog
	WHERE custid=@custid
	
	-- write log
	DECLARE @LogData VARCHAR(4000),	
			@ActionID INT
			
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)	
	
	SELECT @ActionID = 696
			,@LogData = '<R IP="' + COALESCE(@IP,SPACE(1)) + '" />'
	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@Userid = @userid,
			@Custid = @CustID,
			@ActionID = @ActionID,
			@TrackingValue = @LogData,							
			@Duration = @duration
	END TRY
	BEGIN CATCH
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@Userid = @userid,
			@Custid = @CustID,
			@ActionID = @ActionID,
			@TrackingValue = @LogData,			
			@Duration = @duration										
	END CATCH
END
GO