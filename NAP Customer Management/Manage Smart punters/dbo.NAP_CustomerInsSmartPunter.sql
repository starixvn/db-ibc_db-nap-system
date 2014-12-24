 ALTER PROCEDURE [dbo].[NAP_CustomerInsSmartPunter]
	@username	VARCHAR(50),
	@remark		NVARCHAR(200) = '',
	@userid		INT,
	@IP			VARCHAR(30),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
	
AS
	/*
		Created: Johnson
		Date: 2014-06-10
		Task: Insert customer into smart punter list
		DB: DBTXN/CustDB
		
		Revisions:
	*/ 
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT
	SET	@startRun = GETDATE()
	
	Declare @CustID int,
			@RoleID tinyint,
			@Currency int
	
	--Check permission
	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@userid,@funcname='[SmartPunter]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	
	SELECT @CustID = custid, @roleid = roleid 
	FROM customer WITH(NOLOCK)
	WHERE username = @username OR username2 = @username
	
	IF @RoleID <> 1 OR @custid IS NULL
	BEGIN		
		SELECT @ErrMsg = 'This username/nickname is not available.'
				,@ErrCode = 100
		RETURN
	END
	
	IF EXISTS (SELECT 1 FROM SmartPunterList WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN		
		SELECT @ErrMsg = 'Smart punter already existed in the list.'
				,@ErrCode = 102
		RETURN
	END
	
	INSERT INTO SmartPunterList 
		(
		    [custid]
           ,[creator]
           ,[createdate]          
           ,[remark]
		)
	VALUES
		(		
			@CustID,
			@userid, 					
			GETDATE(),						
			@Remark
		)

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 103
		SELECT @ErrMsg = 'Add smart punter unsuccessfuly!'
		RETURN
	END		
	
	-- write log
	DECLARE @LogData NVARCHAR(4000)
	SELECT @LogData = '<Nap_CustomerInsSmartPunter UserName/NickName="' + COALESCE(@UserName,SPACE(1)) + '" ' 
							+ 'Remark="' + COALESCE(@Remark,SPACE(1)) + '" '	
							+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
							+ 'ErrMsg="' + coalesce(@ErrMsg,space(1))+'" '
							+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'																		

	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@Userid = @userid,
			@Custid = @CustID,
			@ActionID = 31000,
			@TrackingValue = @LogData,
			@Duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @LogData = '<Nap_CustomerInsSmartPunter UserName/Nickname="' + COALESCE(@UserName,SPACE(1)) + '" ' 
							+ 'Remark="' + COALESCE(@Remark,SPACE(1)) + '" '	
							+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
							+ 'ErrMsg="' + coalesce(ERROR_MESSAGE(),space(1))+'" '
							+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'	
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@Userid = @userid,
			@Custid = @CustID,
			@ActionID = 31000,
			@TrackingValue = @LogData,
			@Duration = @duration
	END CATCH
	
END
GO

GRANT EXECUTE ON [dbo].[Nap_CustomerInsSmartPunter] TO [bodbAdminNet]