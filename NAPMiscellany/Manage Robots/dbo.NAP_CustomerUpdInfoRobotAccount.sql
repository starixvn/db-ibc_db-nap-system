 ALTER PROCEDURE [dbo].[NAP_CustomerUpdInfoRobotAccount]
	@custid INT,
	@remark VARCHAR(200)= '',
	@userid INT,
	@IP		VARCHAR(30)= '',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT	
AS
	/*
		Created: Johnson
		Date: 2014-05-30
		Task: Update info for robot account
		DB: DBTXN/CustDB
	*/ 
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT
	SET	@startRun = GETDATE()
	
		--Check permission
	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@userid,@funcname='[ManageRobots]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	
	DECLARE @old_remark varchar(200)
	
	SELECT @old_remark = remark FROM RobotList_tmp WITH(NOLOCK) WHERE custid = @custid
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 100,
			@ErrMsg = 'This account doesn''t exist in the monitoring list.'
		RETURN
	END
	
	IF @old_remark = @remark RETURN
	
	UPDATE RobotList_tmp WITH(UPDLOCK,ROWLOCK)
	SET remark = @remark,
		lastmodifyuser = @userid,
		lastmodifytime = GETDATE()
	WHERE custid = @custid 
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'Update account unsuccessfuly.'
		RETURN
	END
	
	-- write log
	DECLARE @LogData VARCHAR(4000),	
			@LogData_Old VARCHAR(4000)

	SELECT @LogData = '<NAP_CustomerUpdInfoRobotAccount CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' 
							+ 'remark="' + COALESCE(@remark,SPACE(1)) + '" '
							+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
							+ 'ErrMsg="' + coalesce(@ErrMsg,space(1))+'" '
							+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'																		

	SELECT @LogData_Old = '<NAP_CustomerUpdInfoRobotAccount CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' 
							+ 'remark="' + COALESCE(@old_remark,SPACE(1)) + '" '	
							+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
							+ 'ErrMsg="' + coalesce(@ErrMsg,space(1))+'" '
							+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
	
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@Userid = @userid,
			@Custid = @CustID,
			@ActionID = 651,
			@TrackingValue = @LogData,
			@TrackingValue2 = @LogData_Old,
			@Duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @LogData = '<NAP_CustomerUpdInfoRobotAccount CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' 
							+ 'remark="' + COALESCE(@remark,SPACE(1)) + '" '
							+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
							+ 'ErrMsg="' + coalesce(ERROR_MESSAGE(),space(1))+'" '
							+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'																		

		SELECT @LogData_Old = '<NAP_CustomerUpdInfoRobotAccount CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' 
								+ 'remark="' + COALESCE(@old_remark,SPACE(1)) + '" '	
								+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
								+ 'ErrMsg="' + coalesce(ERROR_MESSAGE(),space(1))+'" '
								+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
		
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@Userid = @userid,
			@Custid = @CustID,
			@ActionID = 651,
			@TrackingValue = @LogData,
			@TrackingValue2 = @LogData_Old,
			@Duration = @duration								
		
	END CATCH
END


GO

GRANT EXECUTE ON [dbo].[NAP_CustomerUpdInfoRobotAccount] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[NAP_CustomerUpdInfoRobotAccount] TO [vnteam] AS [dbo]
GO


