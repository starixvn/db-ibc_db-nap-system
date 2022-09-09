/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[NAP_Customer_FollowBetAccountDel] 
	@username VARCHAR(30) = '',	
	@DummyAgentID INT,
	
	@userid INT,
	@IP	VARCHAR(30)= '',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg  VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220909@Johnson
	Task: delete follow bet account
	DB: DBCUST/CustDB
	
	Revisions:
		- 20220909@Johnson: initial sp [redmine: #176975]
	
	Paramter's Explanations:
				
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @startRun DATETIME,			
			@duration INT,
			@custid INT 
	
	SELECT @startRun = GETDATE()
	
	SELECT @custid = custid
	FROM customer WITH(NOLOCK)
	WHERE username = @username
	
	IF NOT EXISTS (SELECT 1 FROM Acc_CustFollowBet WITH(NOLOCK)
					WHERE DummyAgentID = @DummyAgentID
						AND custid = @custid
					)
	BEGIN
		SELECT @ErrMsg = 'Invalid account',
			@ErrCode = 100
		RETURN;
	END	
	
	DELETE Acc_CustFollowBet WITH(ROWLOCK)
	WHERE DummyAgentID = @DummyAgentID
		AND custid = @custid
	
	-- write log
	DECLARE @LogData NVARCHAR(4000)
	SELECT @LogData = '<R UserName="' + COALESCE(@UserName,SPACE(1)) + '" ' 														
						+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'																		

	SET @duration  = DATEDIFF(millisecond,@startRun,GETDATE())
	
	
	EXEC Acc_WriteLog_UserLog_RunSP_Wrapper
		@Userid = @userid,
		@Custid = @DummyAgentID,
		@ActionID = 95076,
		@TrackingValue = @LogData,
		@Duration = @duration
END	