/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE CustDB
GO

ALTER PROCEDURE [dbo].[NAP_CustomerUpdStatusRobotAccount]
	@custids VARCHAR(4000),
	@status BIT,
	@userid INT,
	@IP		VARCHAR(30)= '',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT	
AS
	/*
		Created: Johnson
		Date: 2014-05-30
		Task: update status for robot account
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
		
	DECLARE @tmpCust TABLE(custid INT PRIMARY KEY, old_status bit, islog bit default(0) )
	
	INSERT INTO @tmpCust(custid)
	SELECT val
	FROM strSplit (@custids,',')
	
	UPDATE t
	SET old_status = isActive
	FROM @tmpCust t
		INNER JOIN RobotList r WITH(NOLOCK) ON t.custid = r.custid
	WHERE r.isActive <> @status
	
	
	UPDATE r
	SET isActive = @status,
		lastmodifyuser = @userid,
		lastmodifytime = GETDATE()
	FROM RobotList r WITH(UPDLOCK,ROWLOCK)
		INNER JOIN @tmpCust t ON r.custid = t.custid
	WHERE t.old_status is not null
	
	
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	-- write log
	DECLARE @LogData VARCHAR(4000),	
			@LogData_Old VARCHAR(4000),
			@old_status bit,
			@custid INT
			
	WHILE (1=1)
	BEGIN
		UPDATE TOP(1) t
		SET @custid = custid,
			@old_status = old_status,
			islog = 1
		FROM @tmpCust t
		WHERE t.islog = 0 AND t.old_status is NOT NULL
		
		IF @@ROWCOUNT = 0 BREAK
				
		SELECT @LogData = '<NAP_CustomerUpdStatusRobotAccount CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' 
								+ 'status="' + COALESCE(CAST(@status AS varchar(10)),SPACE(1)) + '" '
								+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
								+ 'ErrMsg="' + coalesce(@ErrMsg,space(1))+'" '
								+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'																		

		SELECT @LogData_Old = '<NAP_CustomerUpdStatusRobotAccount CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' 
								+ 'status="' + COALESCE(CAST(@Old_status AS varchar(10)),SPACE(1)) + '" '	
								+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
								+ 'ErrMsg="' + coalesce(@ErrMsg,space(1))+'" '
								+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
				
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@Userid = @userid,
				@Custid = @CustID,
				@ActionID = 650,
				@TrackingValue = @LogData,
				@TrackingValue2 = @LogData_Old,
				@Duration = @duration
		END TRY
		BEGIN CATCH
			SELECT @LogData = '<NAP_CustomerUpdStatusRobotAccount CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' 
								+ 'status="' + COALESCE(CAST(@status AS varchar(10)),SPACE(1)) + '" '
								+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
								+ 'ErrMsg="' + coalesce(ERROR_MESSAGE(),space(1))+'" '
								+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'																		

			SELECT @LogData_Old = '<NAP_CustomerUpdStatusRobotAccount CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' 
									+ 'status="' + COALESCE(CAST(@Old_status AS varchar(10)),SPACE(1)) + '" '	
									+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
									+ 'ErrMsg="' + coalesce(ERROR_MESSAGE(),space(1))+'" '
									+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
			
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@Userid = @userid,
				@Custid = @CustID,
				@ActionID = 650,
				@TrackingValue = @LogData,
				@TrackingValue2 = @LogData_Old,
				@Duration = @duration								
			
		END CATCH
	END
END
GO