/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE CustDB
GO
ALTER PROCEDURE [dbo].[NAP_CustomerInsRobotAccount]
	@usernames varchar(4000),
	@status bit= 1,
	@remark varchar(200) = '',
	@userid int,
	@IP	varchar(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(4000) = '' OUTPUT	
AS
	/*
		Created: Johnson
		Date: 2014-05-30
		Task: Insert robot accounts
		DB: DBCUST/CustDB
		
		Revision:
				- 20171115@Vicky: change location check permission [RedmineID: #86455]
		Parameter's Explanation:
			- ErrCode = 0: success
					> 0 : have some accounts insert fail	
					< 0 : existing customers in robotlist				
	*/ 
BEGIN
	SET NOCOUNT ON 
	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT
	SET	@startRun = GETDATE()
	
		--Check permission
	EXEC DBNAP.bodb_NAP.dbo.NAP_User_CheckPermission @UserId=@userid,@SiteKey='CustomerManagement',@FunctionKey='ManageRobots',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	
	DECLARE @tmpUser TABLE (custid int,username varchar(50))
	DECLARE @tmpCust TABLE (custid int, islog bit)
	
	INSERT INTO @tmpUser(username)
	SELECT val
	FROM strSplit (@usernames,',')
	
	UPDATE t
	SET t.custid = c.custid
	FROM @tmpUser t
		LEFT JOIN customer c WITH(NOLOCK) ON t.username = c.username AND roleid = 1
	
	IF EXISTS (SELECT top (1) 1 FROM @tmpUser WHERE custid IS NULL)
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Invalid username: '
		
		SELECT TOP (100) @ErrMsg = @ErrMsg + username + ','
		FROM @tmpUser
		WHERE custid IS NULL
		
		RETURN
	END
	
	IF EXISTS (SELECT * FROM @tmpUser GROUP BY custid HAVING COUNT(1) <> 1)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'There are duplicated members: '
		
		SELECT TOP (100) @ErrMsg = @ErrMsg + username + ','
		FROM @tmpUser 
		GROUP BY custid, username  
		HAVING COUNT(1) <> 1
		
		RETURN
	END

	IF EXISTS (SELECT TOP(1) 1 FROM RobotList WITH(NOLOCK) WHERE custid IN (SELECT custid FROM @tmpUser))
	BEGIN
		SELECT @ErrCode = -100, @ErrMsg = 'There are existing members : '
		
		SELECT TOP (100) @ErrMsg = @ErrMsg + username + ','
		FROM @tmpUser t 
			INNER JOIN RobotList r WITH(NOLOCK) ON t.custid = r.custid

		RETURN 
	END
		
	INSERT INTO RobotList([custid]
           ,[isActive]
           ,[creator]
           ,[createdate]           
           ,[remark])
    OUTPUT INSERTED.custid,0 INTO @tmpCust
	SELECT t.custid, @status, @userid, GETDATE(), @remark
	FROM @tmpUser t
		LEFT JOIN RobotList r WITH(NOLOCK) ON t.custid = r.custid
	WHERE r.custid IS NULL
	
	IF @@ROWCOUNT <> 0
	BEGIN
		SELECT @ErrMsg = 'The member(s) have been saved successfully!' + @ErrMsg
	END
		-- write log
	DECLARE @LogData VARCHAR(4000),	
			@custid INT,			
			@log_username varchar(50)
			
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)	
	
	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) t
		SET @log_username = username,
			@custid = t.custid,
			islog = 1
		FROM @tmpCust t 
			INNER JOIN @tmpUser u ON t.custid = u.custid
		WHERE islog = 0
		
		IF @@ROWCOUNT = 0 BREAK;
		
		SELECT @LogData = '<NAP_CustomerInsRobotAccount username="' + COALESCE(@log_username,SPACE(1)) + '" ' 
								+ 'status="' + COALESCE(CAST(@status AS varchar(10)),SPACE(1)) + '" '
								+ 'remark="' + COALESCE(@remark,SPACE(1)) + '" '
								+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
								+ 'ErrMsg="' + coalesce(@ErrMsg,space(1))+'" '
								+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'																		
		
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@Userid = @userid,
				@Custid = @CustID,
				@ActionID = 649,
				@TrackingValue = @LogData,				
				@Duration = @duration
		END TRY
		BEGIN CATCH
			SELECT @LogData = '<NAP_CustomerInsRobotAccount username="' + COALESCE(@log_username,SPACE(1)) + '" ' 
									+ 'status="' + COALESCE(CAST(@status AS varchar(10)),SPACE(1)) + '" '
									+ 'remark="' + COALESCE(@remark,SPACE(1)) + '" '
									+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
									+ 'ErrMsg="' + coalesce(ERROR_MESSAGE(),space(1))+'" '
									+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'																		
		
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@Userid = @userid,
				@Custid = @CustID,
				@ActionID = 649,
				@TrackingValue = @LogData,
				@Duration = @duration										
		END CATCH
	END		
END
GO

