/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_UpdateCustomer
	@CustomerList		VARCHAR(MAX),
	@RoleId				TINYINT,
	@ReasonId			TINYINT,
	@PreventActionId	TINYINT,
	@Comment			NVARCHAR(300) = '',
	@VoidTime			VARCHAR(50) = '',
	@LimitAmount		MONEY = 0,
	@UpdateTime			BIT = 0,
	@UpdateLimitAmount 	BIT = 0,

	@UserID				INT,
	@IP					VARCHAR(15),
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 20200210
	Task : Update Preventive Action
	DB: DBCUST/CustDB

	Revisions:
		- 20200210@Elodie: Initial SP [Redmine:#127446]
		- 20200720@Johnson: add void time & limit amount [redmine:#135253]	
	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT, @SubIssueTypeId TINYINT
	DECLARE @SetBit1 INT, @Pos TINYINT, @SuccessDownlineList VARCHAR(MAX) = '', @ReasonName VARCHAR(100), @ActionName VARCHAR(100), @Old_ReasonName VARCHAR(100), @Old_ActionName VARCHAR(100)
	DECLARE @CustId INT, 
			@UserName NVARCHAR(50), 
			@DownlineList VARCHAR(MAX), 
			@Old_ReasonId TINYINT, 
			@Old_PreventActionId TINYINT, 
			@Old_Comment	NVARCHAR(300),
			@Old_VoidTime	VARCHAR(50),
			@Old_LimitAmount MONEY
			
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), 
							CustId INT, 
							Currency INT,
							ReasonId TINYINT, 
							PreventActionId TINYINT, 
							Comment NVARCHAR(300), 
							VoidTime VARCHAR(50),
							LimitAmount MONEY,
							IsFinished BIT DEFAULT(0))	

	SET	@startRun = GETDATE()

	SELECT	@Pos = CASE @RoleId WHEN 4 THEN 3
								WHEN 3 THEN 2
								WHEN 2 THEN 1
								WHEN 1 THEN 0 END					
			
	SELECT @SetBit1 = POWER(2, @Pos)

	SELECT @ReasonName = ReasonName FROM dbo.ProblemAccountReason WITH (NOLOCK) WHERE ReasonID = @ReasonId
	SELECT @ActionName = ActionName FROM dbo.ProblemAccountAction WITH (NOLOCK) WHERE ActionID = @PreventActionId

	SELECT @SubIssueTypeId = SubIssueTypeId 
	FROM dbo.ProblemAccountAction WITH (NOLOCK)
	WHERE ActionId = @PreventActionId

	INSERT INTO @tmpCust(Username, currency, CustID)
	SELECT ci.Username, ci.currency, ci.custid
	FROM dbo.f_StringSplit(@CustomerList, ',') f
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username
	
	IF @PreventActionId = 2 --Void Winning Tickets
		AND @UpdateLimitAmount = 1 AND @LimitAmount > 0
		AND (SELECT COUNT(DISTINCT currency) FROM @tmpCust) > 1
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Multiple currencies selected. To save Limit Amount, all selected accounts must belong to one currency.'
		RETURN
	END
	
	UPDATE t 
	SET t.ReasonId = pa.ReasonId,
		t.PreventActionId = pa.ActionId,
		t.Comment = pa.Comment,
		t.VoidTime = pa.VoidTime,
		t.LimitAmount = pa.LimitAmount
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId

	UPDATE pa 
	SET pa.ProblemStatus = ProblemStatus | @SetBit1,
		pa.ReasonId = @ReasonId,
		pa.ActionId = @PreventActionId,
		pa.Comment = @Comment,
		pa.SubIssueTypeId = CASE WHEN @RoleId = 1 THEN @SubIssueTypeId ELSE NULL END,
		pa.VoidTime = CASE WHEN @UpdateTime = 1 THEN @VoidTime 
							WHEN @UpdateTime = 0 AND @PreventActionId =2 AND t.PreventActionId <> 2 THEN 'At Settlement'
							ELSE pa.VoidTime END,
		pa.LimitAmount = CASE WHEN @UpdateLimitAmount = 1 THEN @LimitAmount 
							WHEN @UpdateLimitAmount = 0 AND @PreventActionId =2 AND t.PreventActionId <> 2 THEN 0
							ELSE pa.LimitAmount END			
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId	

	WHILE (1=1)
	BEGIN		
		UPDATE TOP (1) @tmpCust
		SET isfinished = 1,
			@CustId = custid,
			@UserName = Username,
			@Old_ReasonId = ReasonId,
			@Old_PreventActionId = PreventActionId,
			@Old_Comment = Comment,
			@Old_VoidTime = VoidTime,
			@Old_LimitAmount = LimitAmount
		WHERE isfinished = 0
	
		IF @@ROWCOUNT = 0 BREAK	

		EXEC dbo.Acc_CustomerInfo_Execrep_12
			@CustId = @CustId,
			@RoleId = @RoleId,
			@ReasonId = @ReasonId,
			@PreventActionId = @PreventActionId,
			@Comment = @Comment,
			@VoidTime = @VoidTime,			
			@UpdateTime = @UpdateTime,
			@Action = 'UpdateProblemAcc',
			@SuccessDownlineList = @SuccessDownlineList OUTPUT

		SELECT @Old_ReasonName = ReasonName FROM dbo.ProblemAccountReason WITH (NOLOCK) WHERE ReasonID = @Old_ReasonId
		SELECT @Old_ActionName = ActionName FROM dbo.ProblemAccountAction WITH (NOLOCK) WHERE ActionID = @Old_PreventActionId
		SELECT @LimitAmount = CASE WHEN @UpdateLimitAmount = 1 THEN @LimitAmount 
									WHEN @UpdateLimitAmount = 0 AND @PreventActionId =2 AND @Old_PreventActionId <> 2 THEN 0
									ELSE @Old_LimitAmount END
		SELECT @VoidTime = CASE WHEN @UpdateTime = 1 THEN @VoidTime ELSE @Old_VoidTime END
		
		-- Write log
		DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)
		SELECT  @LogDataOld = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' Reason="' + @Old_ReasonName + '"'							
							+ ' PreventiveAction="' + @Old_ActionName + '"'
							+ ' Comment="' + @Old_Comment + '"'
							+ ' UpdateTime="' + COALESCE(CAST(@UpdateTime as VARCHAR(10)), SPACE(1)) + '"'							
							+ ' UpdateLimitAmount="' + COALESCE(CAST(@UpdateLimitAmount as VARCHAR(10)), SPACE(1)) + '"'							
							+ ' VoidTime="' + COALESCE(@Old_VoidTime, SPACE(1)) + '"'							
							+ ' LimitAmount="' + COALESCE(CASE WHEN @Old_LimitAmount = 0 THEN 'Unlimited' ELSE dbo.f_FomatNumber (CAST(@Old_LimitAmount AS VARCHAR(10))) END, SPACE(1)) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'

		SELECT  @LogDataNew = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' Reason="' + @ReasonName + '"'
							+ ' PreventiveAction="' + @ActionName + '"'
							+ ' Comment="' + @Comment + '"'
							+ ' UpdateTime="' + COALESCE(CAST(@UpdateTime as VARCHAR(10)), SPACE(1)) + '"'							
							+ ' UpdateLimitAmount="' + COALESCE(CAST(@UpdateLimitAmount as VARCHAR(10)), SPACE(1)) + '"'							
							+ ' VoidTime="' + COALESCE(CASE WHEN @UpdateTime = 0 AND @PreventActionId =2 AND @Old_PreventActionId <> 2 
														THEN 'At Settlement' 
														ELSE @VoidTime END, SPACE(1)) + '"'							
							+ ' LimitAmount="' + COALESCE(CASE WHEN @LimitAmount = 0 THEN 'Unlimited' ELSE dbo.f_FomatNumber (CAST(@LimitAmount AS VARCHAR(10))) END, SPACE(1)) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'		

		SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31617,
			@TrackingValue		= @LogDataNew,
			@TrackingValue2		= @LogDataOld,
			@Duration			= @Duration,
			@AffectedDownlines	= @SuccessDownlineList
	END	
END
GO
