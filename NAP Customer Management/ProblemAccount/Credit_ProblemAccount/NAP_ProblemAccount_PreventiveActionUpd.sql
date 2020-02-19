/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_PreventiveActionUpd
	@CustomerList	VARCHAR(MAX),
	@RoleId			TINYINT,
	@ActionId		TINYINT,

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
	DECLARE @CustId INT, @UserName NVARCHAR(50), @DownlineList VARCHAR(MAX), @Old_ActionId TINYINT
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, ActionId TINYINT, IsFinished BIT DEFAULT(0))

	SET	@startRun = GETDATE()

	INSERT INTO @tmpCust(Username, CustID)
	SELECT ci.Username, ci.custid
	FROM dbo.f_StringSplit(@CustomerList, ',') f
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username

	UPDATE t 
	SET t.ActionId = pa.ActionId
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId

	UPDATE pa 
	SET pa.ActionId = @ActionId
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId	

	WHILE (1=1)
	BEGIN		
		UPDATE TOP (1) @tmpCust
		SET isfinished = 1,
			@CustId = custid,
			@UserName = Username,
			@Old_ActionId = ActionId
		WHERE isfinished = 0
	
		IF @@ROWCOUNT = 0 BREAK	

		-- Write log
		DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)
		SELECT  @LogDataOld = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' PreventiveAction="' + CAST (@Old_ActionId AS VARCHAR(5)) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'

		SELECT  @LogDataNew = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' PreventiveAction="' + CAST (@ActionId AS VARCHAR(5)) + '"'
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
