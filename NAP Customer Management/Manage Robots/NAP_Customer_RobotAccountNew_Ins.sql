/*<info serverAlias="DBONUSER-ON_USER" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_Customer_RobotAccountNew_Ins]
	@usernames VARCHAR(MAX),	
	@remark NVARCHAR(500) = '',
	@level TINYINT=0,
	@userid INT,
	@ConfirmUpline BIT = 0,
	@IP	VARCHAR(15)='',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(4000) = '' OUTPUT	
AS
/*
		Created: Johnson
		Date: 2019-09-12
		Task: Insert robot accounts new version
		DB: DBONUSER/ON_USER
		
		Revision:
			- 20190912@Johnson: Initial sp [redmine:#119714]
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
	EXEC DBCUST.NAP_UserControl.dbo.NAP_User_CheckPermission @UserId=@userid,@SiteKey='CustomerManagement',@FunctionKey='ManageRobots2',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	
	DECLARE @tmpUser TABLE (custid INT,roleid TINYINT, site VARCHAR(10),srecommend INT, mrecommend INT, recommend INT, username varchar(50), remark NVARCHAR(500), isExisting BIT DEFAULT(0), islog BIT DEFAULT(0))
	DECLARE @tmpCust TABLE (custid INT, remark NVARCHAR(500))
	
	INSERT INTO @tmpUser(username)
	SELECT LTRIM(RTRIM(val))
	FROM strSplit (@usernames,',')
	
	UPDATE t
	SET custid = c.custid,
		roleid = c.roleid,
		site = c.site,
		srecommend = c.srecommend,
		mrecommend = c.mrecommend,
		recommend = c.recommend
	FROM @tmpUser t
		LEFT JOIN bodb02.dbo.customer c WITH(NOLOCK) ON t.username = c.username
		
	IF EXISTS (SELECT top (1) 1 FROM @tmpUser WHERE custid IS NULL)
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Invalid username: '
		
		SELECT TOP (100) @ErrMsg = @ErrMsg + username + ','
		FROM @tmpUser
		WHERE custid IS NULL
		
		RETURN
	END
	
	IF EXISTS (SELECT top (1) 1 FROM @tmpUser WHERE roleid <> @level)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Account(s) not in the selected level: '
		
		SELECT TOP (100) @ErrMsg = @ErrMsg + username + ','
		FROM @tmpUser
		WHERE roleid <> @level
		
		RETURN
	END
	
	IF @ConfirmUpline = 0
		AND EXISTS (SELECT 1 FROM RobotUsers WITH(NOLOCK) 
				WHERE custid IN (SELECT srecommend FROM @tmpUser WHERE roleid < 4
								UNION SELECT mrecommend FROM @tmpUser WHERE roleid < 3
								UNION SELECT recommend FROM @tmpUser WHERE roleid < 2)
			)
	BEGIN
		SELECT @ErrCode = 103, @ErrMsg = 'Uplines of the following accounts have already been added in the robot list: '
		
		SELECT TOP (100) @ErrMsg = @ErrMsg + username + ','
		FROM @tmpUser
		WHERE EXISTS (SELECT 1 FROM RobotUsers WITH(NOLOCK) 
						WHERE custid IN (SELECT srecommend FROM @tmpUser WHERE roleid < 4
										UNION SELECT mrecommend FROM @tmpUser WHERE roleid < 3
										UNION SELECT recommend FROM @tmpUser WHERE roleid < 2)
						)				
		
		RETURN
	END
	
	IF @level = 1
	BEGIN
		UPDATE t
		SET t.site = c.site
		FROM @tmpUser t
			INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON t.recommend = c.custid		
	END
	
	IF EXISTS (SELECT TOP 1 1 
				FROM @tmpUser t
					INNER JOIN bodb02.dbo.site s WITH(NOLOCK) ON t.site = s.site
				WHERE s.isLicensee = 1
			)
	BEGIN
		SELECT @ErrCode = 104, @ErrMsg = 'Account(s) belongs to licensee sites: '
		
		SELECT TOP (100) @ErrMsg = @ErrMsg + username + ','
		FROM @tmpUser t
			INNER JOIN bodb02.dbo.site s WITH(NOLOCK) ON t.site = s.site
				WHERE s.isLicensee = 1		
		
		RETURN
	END
	
	IF EXISTS(SELECT 1 FROM RobotUsers WITH(NOLOCK) 
			WHERE custid IN (SELECT custid FROM @tmpUser)
			)
	BEGIN
		UPDATE RobotUsers WITH(UPDLOCK,ROWLOCK)
		SET remark = @remark
		OUTPUT DELETED.custid, DELETED.remark INTO @tmpCust(custid,remark)		
		WHERE custid IN (SELECT custid FROM @tmpUser)
		
		UPDATE u
		SET isExisting = 1,
			remark = t.remark
		FROM @tmpUser u
			INNER JOIN @tmpCust t ON u.custid =u.custid		
	END
	
	
	INSERT INTO [dbo].[RobotUsers]
           ([custid]
           ,[IP]
           ,[LastChangeTime]
           ,[site]
           ,[counter]
           ,[serverip]
           ,[RobotDate]
           ,[remark]
		   ,[Creator])
	SELECT t.custid, 'N/A', GETDATE(), t.site, 10, NULL, NULL, @remark, @userid
	FROM @tmpUser t
		LEFT JOIN RobotUsers r WITH(NOLOCK) ON t.custid = r.custid
	WHERE r.custid IS NULL
	
	-- write log
	DECLARE @LogData VARCHAR(4000),	
			@LogData_Old VARCHAR(4000),	
			@custid INT,			
			@isExisting BIT,
			@ActionID INT,
			@old_remark NVARCHAR(500)			
			
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)	
	
	--log for update action
	WHILE (1=1)
	BEGIN
		SELECT @LogData = NULL,
			@LogData_Old = NULL,
			@old_remark = ''
			
		UPDATE TOP (1) u
		SET @custid = custid,
			@isExisting = isExisting,
			@old_remark = remark,
			islog = 1
		FROM @tmpUser u 
		WHERE islog = 0
		
		IF @@ROWCOUNT = 0 BREAK;
		
		IF @isExisting = 1
		BEGIN
			SELECT @ActionID = 694
					,@LogData = '<R remark="' + COALESCE(@remark,SPACE(1)) + '" '									
									+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
					,@LogData_Old = '<R remark="' + COALESCE(@old_remark,SPACE(1)) + '" '									
									+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'					
		END
		ELSE
		BEGIN
			SELECT @ActionID = 695
					,@LogData = '<R remark="' + COALESCE(@remark,SPACE(1)) + '" '									
									+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
		END
		
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@Userid = @userid,
				@Custid = @CustID,
				@ActionID = @ActionID,
				@TrackingValue = @LogData,	
				@TrackingValue2 = @LogData_Old,				
				@Duration = @duration
		END TRY
		BEGIN CATCH
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@Userid = @userid,
				@Custid = @CustID,
				@ActionID = @ActionID,
				@TrackingValue = @LogData,
				@TrackingValue2 = @LogData_Old,
				@Duration = @duration										
		END CATCH
	END	
	
END
GO	