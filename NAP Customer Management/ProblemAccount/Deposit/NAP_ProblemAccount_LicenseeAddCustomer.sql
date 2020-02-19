/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_ProblemAccount_LicenseeAddCustomer]
	@CustomerList	VARCHAR(MAX),	
	@ReasonId		TINYINT,
	@Comment		NVARCHAR(300) = '',

	@UserID			INT,
	@IP				VARCHAR(15),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(MAX) = '' OUTPUT	
AS
/*
	Created: 20200218@Johnson	
	Task : Add new problem account for deposit
	DB: DBCUST/CustDB

	Revisions:
		- 20200218@Johnson: Initial SP [Redmine:#128077]
		
	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT
	DECLARE @WrongUserName VARCHAR(MAX), @CustNumber INT, @today DATE 
	DECLARE @tmpCust TABLE (Username VARCHAR(30), CustId INT, currency INT, MaxBet MONEY, MaxPerEvent MONEY, IsFinished BIT DEFAULT(0))
	
	SELECT @startRun = GETDATE()
	
	INSERT INTO @tmpCust(Username)
	SELECT Val
	FROM dbo.f_StringSplit(@CustomerList, ',') f

	UPDATE t
	SET t.custid = c.custid,
		t.currency = c.currency
	FROM @tmpList t
		INNER JOIN dbo.customer c WITH (NOLOCK) ON t.Username = c.username
	WHERE srecommend IN (SELECT custid FROM)
		AND roleid = 1
		
	----START: Validattion-------------------------------------------------
	SELECT @WrongUserName = STUFF((SELECT ', '+ Username
									FROM @tmpCust c
									WHERE c.CustId IS NULL
									FOR XML PATH('')),1,2,'')

	IF ISNULL(@WrongUserName,'') <> ''
    BEGIN
	   SELECT @ErrCode = 101, @ErrMsg = 'Invalid account(s): ' + @WrongUserName	   
	   RETURN
    END	

	SELECT @WrongUserName = STUFF((SELECT ', '+ Username
									FROM @tmpCust t
										INNER JOIN ProblemAccount p WITH(NOLOCK) ON t.custid = p.custid									
									FOR XML PATH('')),1,2,'')

	IF ISNULL(@WrongUserName,'') <> ''
    BEGIN
	   SELECT @ErrCode = 102, @ErrMsg = 'Existing directly marked problem account(s): ' + @WrongUserName	   
	   RETURN
    END	

	SELECT @CustNumber = COUNT(1) FROM @tmpCust c

	IF @CustNumber > 100
    BEGIN
	   SELECT @ErrCode = 103, @ErrMsg = 'The function can only mark up to 100 accounts per request.'
	   RETURN
    END	
	----END: Validattion-------------------------------------------------	
	SELECT @ReasonName = ReasonName FROM dbo.ProblemAccountReason WITH (NOLOCK) WHERE ReasonID = @ReasonId
	
	SELECT @today = GETDATE()
	
	UPDATE t
	SET MaxBet = ROUND(100*MYR,0),
		MaxPerEvent = ROUND(300*MYR,0)
	FROM @tmpCust t
		INNER JOIN ExchangeDailyOanda e WITH(NOLOCK) ON t.currency = t.ExchangeId
	WHERE ExchangeDate = @today	
		
	INSERT INTO dbo.ProblemAccount (CustId, ProblemStatus, ReasonId, Comment, MaxBet, MaxPerEvent, CreatedDate, IsReviewed, IsAbnormalMember)	
	SELECT CustId, 0, @ReasonID, @Comment, MaxBet, MaxPerEvent, GETDATE(), 0, 0
	FROM @tmpCust t
	WHERE custid IS NOT NULL
	
	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
	DECLARE @LogDataNew VARCHAR(500)
	
	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) @tmpCust
		SET isfinished = 1,
			@CustId = custid,
			@UserName = UserName,
			@MaxBet = MaxBet,
			@MaxPerEvent = MaxPerEvent
		WHERE isfinished = 0
	
		IF @@ROWCOUNT = 0 BREAK

		-- Write log
		SELECT  @LogDataNew = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' Reason="' + @ReasonName + '"'
							+ ' Comment="' + @Comment + '"'
							+ ' MaxBet="'+COALESCE(CAST(@MaxBet AS VARCHAR(10)), SPACE(1))+'"'
							+ ' MaxPerEvent="'+COALESCE(CAST(@MaxPerEvent AS VARCHAR(10)), SPACE(1))+'"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'
	
		EXEC dbo.ACC_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31626,
			@TrackingValue		= @LogDataNew,
			@Duration			= @Duration,		
	END
END
GO
