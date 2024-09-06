/*<info serverAlias="DBAGE-bodb_Age" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_LimitLoss_SMAIsNotificationUpd]  
	@custList	VARCHAR(MAX) = '',	
	@HeadlineList	VARCHAR(MAX) = ''
AS  
/*  

	Created: 20240905@Elodie   
	Task:Update IsNotified Col when SMA is sent notification
	DB: DBAGE/bodb_Age  

	Revisions:  		
		- 20200901@Elodie: Initial sp [redmine:#210405]
		
	Parameter's Explanation: 
		EXEC NAP_LimitLoss_SMAIsNotificationUpd_xtest @custList = '[
			{"CustId": "1362437"},
			{"CustId": "269822"}]',
			@HeadlineList = '[
			{"CustId": "10708", "GroupHeadlineId": 49},
			{"CustId": "4037357", "GroupHeadlineId": 173}
			]'
*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @startRun DATETIME, @EndRun DATETIME, @duration INT, @ModifiedDate DATETIME, @CustId INT, @GroupHeadlineId INT, @LogDataNew VARCHAR(500)
	DECLARE @tblCustList TABLE (custid INT, isFinished BIT DEFAULT(0))
	DECLARE @tblHeadlineList TABLE (custid INT, GroupHeadlineId INT, isFinished BIT DEFAULT(0))

	SET @custList = LTRIM(RTRIM(@custList))
	SET @HeadlineList = LTRIM(RTRIM(@HeadlineList))
	IF ISNULL(@custList,'') = '' OR ISNULL(@HeadlineList,'') = '' 
		RETURN

	SELECT @startRun = GETDATE() , @ModifiedDate = GETDATE()	
	
	INSERT INTO @tblCustList (custid)
	SELECT custId
	FROM OPENJSON(@custList) WITH (
				CustId		INT  '$.CustId'							
		)
	
	INSERT INTO @tblHeadlineList (custid, GroupHeadlineId)
	SELECT custId, GroupHeadlineId
	FROM OPENJSON(@HeadlineList) WITH (
				CustId		INT  '$.CustId'		
				,GroupHeadlineId INT  '$.GroupHeadlineId'
		)

	UPDATE ci
	SET ci.IsNotified = 1
	FROM @tblCustList t
		INNER JOIN LimitLoss_Setting ci WITH(NOLOCK) ON t.custid = ci.custid
	
	UPDATE ci
	SET ci.IsNotified = 1
	FROM @tblHeadlineList t
		INNER JOIN LimitLoss_HeadlineSetting ci WITH(NOLOCK) ON t.GroupHeadlineId = ci.GroupHeadlineId
	
	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) t
		SET isFinished = 1,
			@CustId = custid
		FROM @tblCustList t
		WHERE isFinished = 0			
		
		IF @@ROWCOUNT = 0
			BREAK;
					
		SELECT  @LogDataNew = '<R '
							+ 'IsNotified=1" '
							+ '/>'
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@UserId				= 10278938, --starixIT
				@CustId				= @CustId,
				@ActionId			= 95119,
				@TrackingValue		= @LogDataNew,
				@Duration			= @Duration 			
		END TRY
		BEGIN CATCH
			EXEC DBCUST.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@UserId				= 10278938, --starixIT
				@CustId				= @CustId,
				@ActionId			= 95119,
				@TrackingValue		= @LogDataNew,
				@Duration			= @Duration
		END CATCH		
	END
	
	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) t
		SET isFinished = 1,
			@CustId = custid,
			@GroupHeadlineId = GroupHeadlineId
		FROM @tblHeadlineList t
		WHERE isFinished = 0			
		
		IF @@ROWCOUNT = 0
			BREAK;
			
		SELECT  @LogDataNew = '<R '
							+ 'GroupHeadlineId="' + coalesce(cast(@GroupHeadlineId as varchar(50)),space(1)) + '" ' 
							+ 'IsNotified=1" '
							+ '/>'

		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@UserId				= 10278938, --starixIT
				@CustId				= @CustId,
				@ActionId			= 95120,
				@TrackingValue		= @LogDataNew,
				@Duration			= @Duration 			
		END TRY
		BEGIN CATCH
			EXEC DBCUST.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				@UserId				= 10278938, --starixIT
				@CustId				= @CustId,
				@ActionId			= 95120,
				@TrackingValue		= @LogDataNew,
				@Duration			= @Duration 
		END CATCH			
	END
END	