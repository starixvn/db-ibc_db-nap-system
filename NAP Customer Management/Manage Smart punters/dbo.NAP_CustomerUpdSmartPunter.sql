 /*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
 ALTER PROCEDURE [dbo].[NAP_CustomerUpdSmartPunter]
	@custid		INT,
	@remark	NVARCHAR(200) = '',
	@userid		INT,
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(4000) = '' OUTPUT	
 AS
 /*
	Created: Johnson
	Date:2014-06-11
	Task: Update smart punter info
	DB: DBCUST/CustDB
	
	Revisions:
		- 20171115@Vicky: change location check permission [RedmineID: #86455]
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
		- 20241230@July: Scale Out DBCUST - Apply Inhouse replication for the remaning tables [Redmine: #215627]

	Parameter's Explanation:
 */
 BEGIN
	SET NOCOUNT ON 
	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT
	SET	@startRun = GETDATE()
	
	--Check permission
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission @UserId=@userid,@SiteKey='CustomerManagement',@FunctionKey='ManageSmartPunters',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	
	IF NOT EXISTS (SELECT 1 FROM SmartPunterList WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN		
		SELECT @ErrMsg = 'This account doesn''t exist in the list.',
			@ErrCode = 100
		RETURN
	END
		
	DECLARE @Old_Remark NVARCHAR(200)
	
	SELECT @Old_Remark = Remark 
	FROM SmartPunterList WITH(NOLOCK) 
	WHERE CustID = @CustID
	
	UPDATE SmartPunterList WITH(ROWLOCK,UPDLOCK)
	SET	Remark = @Remark,
		lastmodifytime = GETDATE(),
		lastmodifyuser = @userid,
		RepUpdateTime = dbo.f_GetDateTime2()
	WHERE CustID = @CustID
	
	IF @@ERROR <> 0
	BEGIN		
		SELECT @ErrMsg = 'Update smart punter unsuccessfuly!',
			@ErrCode = 101
		RETURN
	END
	
	-- write log
	DECLARE @LogData NVARCHAR(4000),	
			@LogData_Old NVARCHAR(4000)

	SELECT @LogData = '<Nap_CustomerUpdSmartPunter CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' 
							+ 'Remark="' + COALESCE(@Remark,SPACE(1)) + '" '
							+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
							+ 'ErrMsg="' + coalesce(@ErrMsg,space(1))+'" '
							+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'																		

	SELECT @LogData_Old = '<Nap_CustomerUpdSmartPunter CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' 
							+ 'Remark="' + COALESCE(@Old_Remark,SPACE(1)) + '" '	
							+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
							+ 'ErrMsg="' + coalesce(@ErrMsg,space(1))+'" '
							+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
	
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@Userid = @userid,
			@Custid = @CustID,
			@ActionID = 31001,
			@TrackingValue = @LogData,
			@TrackingValue2 = @LogData_Old,
			@Duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @LogData = '<Nap_CustomerUpdSmartPunter CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' 
							+ 'Remark="' + COALESCE(@Remark,SPACE(1)) + '" '
							+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
							+ 'ErrMsg="' + coalesce(ERROR_MESSAGE(),space(1))+'" '
							+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'																		

		SELECT @LogData_Old = '<Nap_CustomerUpdSmartPunter CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)),SPACE(1)) + '" ' 
							+ 'Remark="' + COALESCE(@Old_Remark,SPACE(1)) + '" '	
							+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '
							+ 'ErrMsg="' + coalesce(ERROR_MESSAGE(),space(1))+'" '
							+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@Userid = @userid,
			@Custid = @CustID,
			@ActionID = 31001,
			@TrackingValue = @LogData,
			@TrackingValue2 = @LogData_Old,
			@Duration = @duration
	END CATCH
	
	
 END
 GO