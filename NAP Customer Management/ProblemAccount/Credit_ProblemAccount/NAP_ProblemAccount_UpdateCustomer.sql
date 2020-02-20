/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_UpdateCustomer
	@CustomerList	VARCHAR(MAX),
	@RoleId			TINYINT,
	@ReasonId		TINYINT,
	@ActionId		TINYINT,
	@Comment		NVARCHAR(300) = '',

	@UserID			INT,
	@IP				VARCHAR(15),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 20200210
	Task : Update Preventive Action
	DB: DBCUST/CustDB

	Revisions:
		- 20200210@Elodie: Initial SP [Redmine:#127446]

	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT
	DECLARE @CustId INT, @UserName NVARCHAR(50), @DownlineList VARCHAR(MAX), @Old_ReasonId TINYINT, @Old_ActionId TINYINT, @Old_Comment	NVARCHAR(300)
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, ReasonId TINYINT, ActionId TINYINT, Comment NVARCHAR(300), IsFinished BIT DEFAULT(0))

	IF NOT EXISTS (SELECT 1 FROM dbo.ProblemAccountReasonAction WITH (NOLOCK) WHERE ReasonId = @ReasonId AND ActionId = @ActionId)
	BEGIN
	   SELECT @ErrCode = 100, @ErrMsg = 'The selected reason is not available for this preventive action'   
	   RETURN
    END

	SET	@startRun = GETDATE()

	INSERT INTO @tmpCust(Username, CustID)
	SELECT ci.Username, ci.custid
	FROM dbo.f_StringSplit(@CustomerList, ',') f
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username

	UPDATE t 
	SET t.ReasonId = pa.ReasonId,
		t.ActionId = pa.ActionId,
		t.Comment = pa.Comment
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId

	UPDATE pa 
	SET pa.ReasonId = @ReasonId,
		pa.ActionId = @ActionId,
		pa.Comment = @Comment
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId	

	WHILE (1=1)
	BEGIN		
		UPDATE TOP (1) @tmpCust
		SET isfinished = 1,
			@CustId = custid,
			@UserName = Username,
			@Old_ReasonId = ReasonId,
			@Old_ActionId = ActionId,
			@Old_Comment = Comment
		WHERE isfinished = 0
	
		IF @@ROWCOUNT = 0 BREAK	

		-- Write log
		DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)
		SELECT  @LogDataOld = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' Reason="' + CAST (@Old_ReasonId AS VARCHAR(5)) + '"'							
							+ ' PreventiveAction="' + CAST (@Old_ActionId AS VARCHAR(5)) + '"'
							+ ' Comment="' + @Old_Comment + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'

		SELECT  @LogDataNew = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' Reason="' + CAST (@ReasonId AS VARCHAR(5)) + '"'
							+ ' PreventiveAction="' + CAST (@ActionId AS VARCHAR(5)) + '"'
							+ ' Comment="' + @Comment + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'		

		SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31617,
			@TrackingValue		= @LogDataNew,
			@TrackingValue2		= @LogDataOld,
			@Duration			= @Duration
	END	
END
GO
