/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_ProblemAccount_AddCustomer]
	@CustomerList		VARCHAR(MAX),
	@RoleId				TINYINT,
	@ReasonId			TINYINT,
	@PreventActionId	TINYINT,
	@Comment			NVARCHAR(300) = '',

	@UserID				INT,
	@IP					VARCHAR(15),
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(MAX) = '' OUTPUT,
	@SuccessList		VARCHAR(MAX) = '' OUTPUT, 
	@FailList			VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 20200210
	Task : Add new problem account for credit site
	DB: DBCUST/CustDB

	Revisions:
		- 20200210@Elodie: Initial SP [Redmine:#127446]

	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT
	DECLARE @WrongUserName VARCHAR(MAX), @CustNumber INT, @CustId INT, @UserName VARCHAR(30), @ReasonName VARCHAR(100), @ActionName VARCHAR(100)
	DECLARE @IsSuccess BIT, @SuccessDownlineList VARCHAR(MAX) = ''
	DECLARE @tmpList TABLE (Username VARCHAR(MAX))	
	DECLARE @tmpCust TABLE (Username VARCHAR(30), CustId INT, RoleId TINYINT, IsFinished BIT DEFAULT(0))	

	INSERT INTO @tmpList(Username)
	SELECT Val
	FROM dbo.f_StringSplit(@CustomerList, ',') f

	INSERT INTO @tmpCust(Username, CustID, RoleId)
	SELECT c.Username, c.custid, c.roleid
	FROM @tmpList t
		INNER JOIN dbo.customer c WITH (NOLOCK) ON t.Username = c.username		
	WHERE c.site <> 'CN88' 
		AND NOT EXISTS (SELECT custid FROM dbo.Dep_CustSuper WITH (NOLOCK) WHERE custid = c.srecommend)
	
	----START: Validattion-------------------------------------------------
	SELECT @WrongUserName = STUFF((SELECT ', '+ l.Username
									FROM @tmpList l
										LEFT JOIN @tmpCust c ON c.Username = l.Username
									WHERE c.CustId IS NULL
									FOR XML PATH('')),1,2,'')

	IF ISNULL(@WrongUserName,'') <> ''
    BEGIN
	   SELECT @ErrCode = 101, @ErrMsg = 'Invalid account(s): ' + @WrongUserName	   
	   RETURN
    END	

	SELECT @WrongUserName = STUFF((SELECT ', '+ Username
									FROM @tmpCust
									WHERE RoleId <> @RoleId
									FOR XML PATH('')),1,2,'')

	IF ISNULL(@WrongUserName,'') <> ''
    BEGIN
	   SELECT @ErrCode = 102, @ErrMsg = 'Account(s) not in the selected level: ' + @WrongUserName	   
	   RETURN
    END	

	SELECT @WrongUserName = STUFF((SELECT ', '+ c.Username
									FROM @tmpCust c
										INNER JOIN dbo.ProblemAccount pa ON pa.CustId = c.CustId
									WHERE pa.ReasonId IS NOT NULL
									FOR XML PATH('')),1,2,'')

	IF ISNULL(@WrongUserName,'') <> ''
    BEGIN
	   SELECT @ErrCode = 103, @ErrMsg = 'Existing directly marked problem account(s): ' + @WrongUserName	   
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
	SELECT @ActionName = ActionName FROM dbo.ProblemAccountAction WITH (NOLOCK) WHERE ActionID = @PreventActionId

	WHILE (1=1)
	BEGIN
		SET	@startRun = GETDATE()

		UPDATE TOP (1) @tmpCust
		SET isfinished = 1,
			@CustId = custid,
			@UserName = UserName
		WHERE isfinished = 0
	
		IF @@ROWCOUNT = 0 BREAK

		EXEC dbo.Acc_CustomerInfo_Execrep_12
			@CustId = @CustId,
			@RoleId = @RoleId,
			@ReasonId = @ReasonId,
			@PreventActionId = @PreventActionId,
			@Comment = @Comment,
			@Action = 'MarkProblem',
			@IsSuccess = @IsSuccess OUTPUT,
			@SuccessDownlineList = @SuccessDownlineList OUTPUT
	
		IF @IsSuccess = 1
			SELECT @SuccessList = @SuccessList + ', ' + @UserName
		ELSE
			SELECT @FailList = @FailList + ', ' + @UserName

		SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

		-- Write log
		DECLARE @LogDataNew VARCHAR(500)
		SELECT  @LogDataNew = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' Reason="' + @ReasonName + '"'
							+ ' PreventiveAction="' + CAST (@ActionName AS VARCHAR(5)) + '"'
							+ ' Comment="' + @Comment + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'
	
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31613,
			@TrackingValue		= @LogDataNew,
			@Duration			= @Duration,
			@AffectedDownlines	= @SuccessDownlineList
	END

	IF ISNULL(@SuccessList,'') <> ''
    BEGIN
	   SELECT @SuccessList = STUFF(@SuccessList,1,2,'')
    END

	IF ISNULL(@FailList,'') <> ''
    BEGIN
	   SELECT @ErrCode = 500, @FailList = STUFF(@FailList,1,2,'')
    END
END
GO
