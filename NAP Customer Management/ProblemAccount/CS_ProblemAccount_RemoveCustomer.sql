/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[CS_ProblemAccount_RemoveCustomer]
	@CustomerList				VARCHAR(MAX),
	@RoleId						TINYINT,
	@ExcludeAbnormalMember		BIT,
	@ExcludeDirectMark			BIT,

	@UserID						INT,
	@IP							VARCHAR(15),
	@ErrCode					INT = 0 OUTPUT,
	@ErrMsg						NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 20190808
	Task : Unmark problem account
	DB: DBCUST/CustDB

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]
		- 20191218@Percy: Change using SP CS_DynamicCustSetting_01 to CS_DynamicCustomerInfo_02 [RedmineID: #125186]

	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT, @ActionId INT
	DECLARE @CustId INT, @UserName NVARCHAR(50), @SuccessDownlineList VARCHAR(MAX) = ''
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, IsFinished BIT DEFAULT(0))

	SET	@startRun = GETDATE()

	INSERT INTO @tmpCust(Username, CustID)
	SELECT ci.Username, ci.custid
	FROM dbo.f_StringSplit(@CustomerList, ',') f
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username
	OPTION (MAXRECURSION 0)

	DELETE pa 
	FROM dbo.CS_ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId	

	WHILE (1=1)
	BEGIN		
		UPDATE TOP (1) @tmpCust
		SET isfinished = 1,
			@CustId = custid,
			@UserName = Username
		WHERE isfinished = 0
	
		IF @@ROWCOUNT = 0 BREAK	
		
		IF @RoleId <> 1
		BEGIN
			EXEC dbo.CS_DynamicCustomerInfo_02
				@CustId = @CustId,
				@RoleId = @RoleId,
				@Action = 'UnmarkProblem',
				@ExcludeAbnormalMember = @ExcludeAbnormalMember,
				@ExcludeDirectMark = @ExcludeDirectMark, 
				@SuccessDownlineList = @SuccessDownlineList OUTPUT
		END

		SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

		-- Write log
		DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)
		IF @RoleId = 1
		BEGIN
			SELECT @ActionId = 31611
			SELECT  @LogDataNew = '<R'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'		
		END
		ELSE
		BEGIN
			SELECT @ActionId = 31607
			SELECT  @LogDataNew = '<R'
								+ ' Username="' + @UserName + '"'								
								+ ' ExcludeAbnormal="' + CAST (@ExcludeAbnormalMember AS VARCHAR(1)) + '"'
								+ ' ExcludeDirectMark="' + CAST (@ExcludeDirectMark AS VARCHAR(1)) + '"'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'		
		END

		EXEC dbo.CS_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionId,
			@TrackingValue		= @LogDataNew,
			@Duration			= @Duration,
			@AffectedDownlines	= @SuccessDownlineList
	END	
END
GO
