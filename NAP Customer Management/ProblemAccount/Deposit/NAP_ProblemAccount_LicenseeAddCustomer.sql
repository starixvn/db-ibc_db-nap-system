/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_ProblemAccount_LicenseeAddCustomer]
	@CustomerList	VARCHAR(MAX),	
	@ReasonId		TINYINT,
	@ActionId		TINYINT,
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
		- 20200327@Johnson: Wrongly convert exchange rate of Reduce Bet Limit [redmine:#131318]
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
			
	DECLARE @tmpCust TABLE (Username VARCHAR(30), CustId INT, currency INT, isVip BIT, isAcknowledgement BIT, MaxBet MONEY, MaxPerEvent MONEY, IsFinished BIT DEFAULT(0))
	
	SELECT @startRun = GETDATE()
	
	INSERT INTO @tmpCust(Username)
	SELECT Val
	FROM dbo.strSplit(@CustomerList, ',') f

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

	SELECT @CustNumber = COUNT(1) FROM @tmpCust c

	IF @CustNumber > 100
    BEGIN
		SELECT @ErrCode = 103, @ErrMsg = 'The function can only mark up to 100 accounts per request.'
		RETURN
    END	
		
	----END: Validattion-------------------------------------------------	
	SELECT @ReasonName = ReasonName FROM dbo.ProblemAccountReason WITH (NOLOCK) WHERE ReasonID = @ReasonId
	SELECT @ActionName = ActionName FROM ProblemAccountAction WITH(NOLOCK) WHERE ActionID = @ActionID
	SELECT @SubIssueTypeId = CASE WHEN @ActionID = 2 THEN 38 ELSE NULL END
	
	SELECT @today = GETDATE()
	
	UPDATE t
	SET MaxBet = ISNULL(ROUND(100/NULLIF(ISNULL(CNY,0),0),0),0),
		MaxPerEvent = ISNULL(ROUND(300/NULLIF(ISNULL(CNY,0),0),0),0)
	FROM @tmpCust t
		INNER JOIN ExchangeDailyOanda e WITH(NOLOCK) ON t.currency = e.ExchangeId
	WHERE ExchangeDate = @today
		AND isAcknowledgement = 1
		AND isVip = 0
		
	INSERT INTO dbo.ProblemAccount (CustId, ProblemStatus, ReasonId, ActionID, Comment, MaxBet, MaxPerEvent, CreatedDate, IsReviewed, IsAbnormalMember, SubIssueTypeId)	
	SELECT CustId, 0, @ReasonID, @ActionID, @Comment, MaxBet, MaxPerEvent, GETDATE(), 0, 0, @SubIssueTypeId
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
