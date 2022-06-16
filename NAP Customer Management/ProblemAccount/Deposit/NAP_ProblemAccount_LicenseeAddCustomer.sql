/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_ProblemAccount_LicenseeAddCustomer]
	@CustomerList	VARCHAR(MAX),	
	@ReasonId		TINYINT,
	@ActionId		TINYINT,
	@Comment		NVARCHAR(300) = '',
	@VoidTime		VARCHAR(50) = '',
	@LimitAmount 	MONEY = 0,
	
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
		- 20200327@Johnson: Wrongly convert exchange rate of Reduce Bet Limit [redmine:#131318]
		- 20200721@Johnson: add void time & limit amount [redmine:#135253]
		- 20220422@Johnson: Add Creator into ProblemAccount [redmine:#171686]
		- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT
	DECLARE @CustId INT, 
			@UserName VARCHAR(50),
			@WrongUserName VARCHAR(MAX), 
			@CustNumber INT, 
			@today DATE, 
			@ReasonName VARCHAR(100),
			@ActionName VARCHAR(100),
			@MaxBet MONEY,
			@MaxPerEvent MONEY, 
			@SubIssueTypeId TINYINT
			
	DECLARE @tmpCust TABLE (Username VARCHAR(30), 
							CustId INT, 
							currency INT, 
							isVip BIT, 
							isAcknowledgement BIT, 
							MaxBet MONEY, 
							MaxPerEvent MONEY, 
							IsFinished BIT DEFAULT(0))
	
	SELECT @startRun = GETDATE()
	
	INSERT INTO @tmpCust(Username)
	SELECT value
	FROM STRING_SPLIT(@CustomerList, ',') f
	WHERE value <> ''

	UPDATE t
	SET t.custid = c.custid,
		t.currency = c.currency,
		t.isAcknowledgement = ISNULL(l.IsAcknowledgement,0),
		t.isVip = CASE WHEN cv.custid IS NULL THEN 0 ELSE 1 END
	FROM @tmpCust t
		INNER JOIN dbo.customer c WITH (NOLOCK) ON t.Username = c.username		
		INNER JOIN Dep_CustSuper d WITH(NOLOCK) ON c.srecommend = d.custid
		LEFT JOIN bodb_Licensee.dbo.Licensees l WITH(NOLOCK) ON d.site = l.LicenseeName
		LEFT JOIN Dep_CustVip cv WITH(NOLOCK) ON c.custid = cv.custid		
	WHERE roleid = 1
			
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
	
	IF (SELECT COUNT(DISTINCT currency) FROM @tmpCust) > 1
		AND @LimitAmount > 0
	BEGIN
		SELECT @ErrCode = 103, @ErrMsg = 'Multiple currencies selected. To save Limit Amount, all selected accounts must belong to one currency.'
		RETURN
	END
	
	SELECT @CustNumber = COUNT(1) FROM @tmpCust c

	IF @CustNumber > 100
    BEGIN
		SELECT @ErrCode = 104, @ErrMsg = 'The function can only mark up to 100 accounts per request.'
		RETURN
    END	
		
	----END: Validattion-------------------------------------------------	
	SELECT @ReasonName = ReasonName FROM dbo.ProblemAccountReason WITH (NOLOCK) WHERE ReasonID = @ReasonId
	SELECT @ActionName = ActionName FROM ProblemAccountAction WITH(NOLOCK) WHERE ActionID = @ActionID
	SELECT @SubIssueTypeId = CASE WHEN @ActionID = 2 THEN 38 ELSE NULL END
	
	SELECT @today = GETDATE()
	
	UPDATE t
	SET MaxBet = CASE WHEN t.currency = 20 THEN 100 ELSE ISNULL(ROUND(100/NULLIF(ISNULL(CNY,0),0),0),0) END,
		MaxPerEvent = CASE WHEN t.currency = 20 THEN 300 ELSE ISNULL(ROUND(300/NULLIF(ISNULL(CNY,0),0),0),0) END
	FROM @tmpCust t
		INNER JOIN ExchangeDailyOanda e WITH(NOLOCK) ON t.currency = e.ExchangeId
	WHERE ExchangeDate = @today
		AND isAcknowledgement = 1
		AND isVip = 0
		
	INSERT INTO dbo.ProblemAccount (CustId, ProblemStatus, ReasonId, ActionID, Comment, MaxBet, MaxPerEvent, CreatedDate, IsReviewed, IsAbnormalMember, SubIssueTypeId, VoidTime, LimitAmount, Creator)	
	SELECT CustId, 0, @ReasonID, @ActionID, @Comment, MaxBet, MaxPerEvent, GETDATE(), 0, 0, @SubIssueTypeId, @VoidTime, @LimitAmount, @UserID
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
							+ ' PreventiveAction="' + @ActionName + '"'
							+ ' Comment="' + @Comment + '"'
							+ ' MaxBet="'+COALESCE(dbo.f_FomatNumber (CAST(@MaxBet AS VARCHAR(10))), SPACE(1))+'"'
							+ ' MaxPerMatch="'+COALESCE(dbo.f_FomatNumber (CAST(@MaxPerEvent AS VARCHAR(10))), SPACE(1))+'"'
							+ ' Time="' + COALESCE(@VoidTime, SPACE(1)) + '"'
							+ ' LimitAmount="' + COALESCE(CASE WHEN @LimitAmount = 0 THEN 'Unlimited' ELSE dbo.f_FomatNumber (CAST(@LimitAmount AS VARCHAR(10))) END, SPACE(1)) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'
	
		EXEC dbo.ACC_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31626,
			@TrackingValue		= @LogDataNew,
			@Duration			= @Duration		
	END
END
GO
