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
			- 20191125@Johnson: add country,region [redmine:#122642]
			- 20200205@Johnson: call sp wrapper from DBCUST to write log [redmine:#127911]
		Parameter's Explanation:			
*/ 
BEGIN
	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT
	SET	@startRun = GETDATE()
	
		--Check permission
	EXEC DBCUST.NAP_UserControl.dbo.NAP_User_CheckPermission @UserId=@userid,@SiteKey='CustomerManagement',@FunctionKey='ManageRobots2',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	
	IF NOT EXISTS (SELECT top (1) 1 FROM RobotUsers WITH(NOLOCK) WHERE custid = @custid)
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Invalid account.'
		RETURN
	END
	
	DELETE RobotUsers with (ROWLOCK) 
	OUTPUT getdate(), deleted.custid, deleted.[IP], deleted.countryLong,deleted.ipRegion, deleted.LastChangeTime, deleted.[site], deleted.[counter], deleted.[serverip], deleted.[RobotDate], deleted.remark, deleted.creator 
	INTO RobotUsers_DelLog ([DelLogDate],[custid],[IP],countryLong,ipRegion,[LastChangeTime],[site],[counter],[serverip],[RobotDate],[remark],[Creator])
	WHERE custid=@custid
	
	-- write log
	DECLARE @LogData NVARCHAR(4000),	
			@ActionID INT
			
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)	
	
	SELECT @ActionID = 696
			,@LogData = '<R IP="' + COALESCE(@IP,SPACE(1)) + '" />'
	
	EXEC DBCUST.CUSTDB.dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserID = @UserID,
		@CustID = @CustID, 
		@ActionID = @ActionID, 
		@TrackingValue = @LogData,
		@duration = @duration
END
GO