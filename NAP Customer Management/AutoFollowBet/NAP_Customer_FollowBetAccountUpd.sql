/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[NAP_Customer_FollowBetAccountUpd] 
	@username VARCHAR(30) = '',	
	@DummyAgentID INT,
	@IsActive BIT,
	
	@userid INT,
	@IP	VARCHAR(30)= '',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg  VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220909@Johnson
	Task: update active status for follow bet account
	DB: DBCUST/CustDB
	
	Revisions:
		- 20220909@Johnson: initial sp [redmine: #176975]
	
	Paramter's Explanations:
				
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @startRun DATETIME, 
			@duration INT,
			@Old_IsActive BIT,
			@custid INT,
			@DummyAgent VARCHAR(30)
	
	SELECT @startRun = GETDATE()
	
	SELECT @custid = custid 
	FROM customer WITH(NOLOCK)
	WHERE username = @username
	
	SELECT @DummyAgent = username 
	FROM customer WITH(NOLOCK)
	WHERE custid = @DummyAgentID
	
	SELECT @Old_IsActive= isActive
	FROM Acc_CustFollowBet WITH(NOLOCK)
	WHERE DummyAgentID = @DummyAgentID
		AND custid = @custid
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrMsg = 'Invalid account',
			@ErrCode = 100
		RETURN;
	END	
	
	IF @Old_IsActive = @IsActive 
		RETURN;
		
	UPDATE Acc_CustFollowBet WITH(ROWLOCK)
	SET IsActive = @IsActive,
		ModifiedDate = GETDATE()
	WHERE DummyAgentID = @DummyAgentID
		AND custid = @custid
	
	-- write log
	DECLARE @LogData NVARCHAR(4000),
			@LogData2 NVARCHAR(4000)
			
	SELECT @LogData = '<R UserName="' + COALESCE(@UserName,SPACE(1)) + '" ' 						
						+ 'DummyAgent="' + coalesce(@DummyAgent,space(1))+'" '
						+ 'IsActive="' + coalesce(cast(@IsActive as varchar(10)),space(1)) + '" '
						+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'	

	SELECT @LogData2 = '<R UserName="' + COALESCE(@UserName,SPACE(1)) + '" ' 						
						+ 'DummyAgent="' + coalesce(@DummyAgent,space(1))+'" '
						+ 'IsActive="' + coalesce(cast(@Old_IsActive as varchar(10)),space(1)) + '" '						
						+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'							

	SET @duration  = DATEDIFF(millisecond,@startRun,GETDATE())
	
	
	EXEC Acc_WriteLog_UserLog_RunSP_Wrapper
		@Userid = @userid,
		@Custid = @custid,
		@ActionID = 95075,
		@TrackingValue = @LogData,
		@TrackingValue2 = @LogData2,
		@Duration = @duration
END	