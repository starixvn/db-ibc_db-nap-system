/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[NAP_Customer_FollowBetAccountIns] 
	@DummyAgentID INT,	
	@CustList VARCHAR(MAX) = '',
	
	@userid INT,
	@IP	VARCHAR(30)= '',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg  VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220907@Johnson
	Task: Add follow bet accounts 
	DB: DBCUST/CustDB
	
	Revisions:
		- 20220907@Johnson: initial sp [redmine: #176975]
	
	Paramter's Explanations:
		- @CustList = 'member01,member02'
		
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @startRun DATETIME, 
			@duration INT,
			@strUsername VARCHAR(MAX) ='',
			@DummyAgent VARCHAR(30),
			@DummyUsernameList VARCHAR(MAX) = '',
			@maxID INT
	
	SELECT @startRun = GETDATE()
	
	DECLARE @tmpCust TABLE (ID INT PRIMARY KEY IDENTITY(1,1),username VARCHAR(30), custid INT)
	
	INSERT INTO @tmpCust(username)
	SELECT value FROM STRING_SPLIT(@CustList,',')
	
	UPDATE t
	SET t.custid = c.custid
	FROM @tmpCust t
		INNER JOIN customer c WITH(NOLOCK) ON t.username = c.username
	WHERE c.roleid = 1	
	
	IF EXISTS (SELECT 1 FROM @tmpCust WHERE custid IS NULL)
	BEGIN
		SELECT @strUsername = ''
		SELECT @strUsername = @strUsername + ',' + username
		FROM @tmpCust
		WHERE custid IS NULL
		
		SELECT @strUsername = STUFF(@strUsername,1,1,'')
		
		SELECT @ErrMsg = 'Invalid account(s): ' + @strUsername,
			@ErrCode = 100
		RETURN
	END
		
	SELECT @strUsername = ''
	SELECT @strUsername = @strUsername + ',' + c.username
	FROM Acc_CustFollowBet cf WITH(NOLOCK)
		INNER JOIN customer c WITH(NOLOCK) ON c.custid = cf.custid
	WHERE DummyAgentID = @DummyAgentID
		AND cf.custid IN (SELECT custid FROM @tmpCust)
	
	IF @strUsername <> ''
	BEGIN
		SELECT @strUsername = STUFF(@strUsername,1,1,'')
		
		SELECT @ErrMsg = 'Existing account(s): ' + @strUsername,
			@ErrCode = 101
		RETURN
	END
	
	SELECT @DummyAgent = username
	FROM customer WITH(NOLOCK)
	WHERE custid = @DummyAgentID
	
	SELECT @maxID = MAX(CAST(REPLACE(DummyUsername,@DummyAgent,'') AS INT))
	FROM Acc_CustFollowBet WITH(NOLOCK)
	WHERE DummyAgentID = @DummyAgentID
	
	INSERT INTO [dbo].[Acc_CustFollowBet]
           ([CustID]
           ,[DummyAgentID]
           ,[DummyUsername]
           ,[Creator]
           ,[isActive]
           ,[CreatedDate]
           ,[ModifiedDate])
	SELECT custid, @DummyAgentID, @DummyAgent + CAST((ID+ISNULL(@maxID,0)) AS VARCHAR(10)),
			@userid, 1 as isActive, GETDATE(), GETDATE()
	FROM @tmpCust
	
	SELECT @DummyUsernameList = @DummyUsernameList + ',' + @DummyAgent + CAST((ID+ISNULL(@maxID,0)) AS VARCHAR(10))
	FROM @tmpCust
	
	SELECT @DummyUsernameList = STUFF(@DummyUsernameList,1,1,'')
	
	-- write log
	DECLARE @LogData NVARCHAR(4000)
	SELECT @LogData = '<R UserName="' + COALESCE(@CustList,SPACE(1)) + '" ' 							
						+ 'DummyUsername="' + coalesce(@DummyUsernameList,space(1))+'" '
						+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'																		

	SET @duration  = DATEDIFF(millisecond,@startRun,GETDATE())
	
	EXEC Acc_WriteLog_UserLog_RunSP_Wrapper
		@Userid = @userid,
		@Custid = @DummyAgentID,
		@ActionID = 95074,
		@TrackingValue = @LogData,
		@Duration = @duration
		
END	