/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_ProblemAccount_RemoveCustomer]
	@CustomerList				VARCHAR(MAX),
	@RoleId						TINYINT,
	@ExcludeAbnormalMember		BIT,
	@ExcludeDirectMark			BIT,

	@UserID						INT,
	@IP							VARCHAR(15),
	@SuccessAllDownlineList		VARCHAR(MAX) = '' OUTPUT,
	@ErrCode					INT = 0 OUTPUT,
	@ErrMsg						NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 20200210
	Task : Unmark problem account for credit site
	DB: DBCUST/CustDB

	Revisions:
		- 20200210@Elodie: Initial SP [Redmine:#127446]
		- 20201016@Elodie: Output all downline list is removed PA [Redmine:#141756]
		- 20201214@Johnson: check & output result status when unmark PA for member level [redmine:#146400]
		- 20210625@Johnson: Unmark multiple SMA PA accounts [redmine:#155453]
	Parameter's explaination: 
		-tblError result:
			* 100: invalid accounts
			* 101: unmarked problem accounts
			* 102: Non-Member Accounts
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT, @ActionId INT
	DECLARE @CustId INT, @UserName NVARCHAR(50), @SuccessDownlineList VARCHAR(MAX) = ''
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, roleid TINYINT, isPA BIT DEFAULT 0, isDeposit BIT, IsFinished BIT DEFAULT(0))	
	DECLARE @strUsername VARCHAR(MAX) = ''
	
	SET	@startRun = GETDATE()

	INSERT INTO @tmpCust(Username, CustID, roleid,isDeposit)
	SELECT DISTINCT f.val, ci.custid, ci.roleid, CASE WHEN s.custid IS NOT NULL THEN 1 ELSE 0 END as isDeposit
	FROM dbo.f_StringSplit(@CustomerList, ',') f
		LEFT JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username
		LEFT JOIN dbo.Dep_CustSuper s WITH(NOLOCK) ON ci.srecommend = s.custid
	OPTION (MAXRECURSION 0)
	
	
	SELECT @strUsername = ''
	
	--check invalid accounts	
	SELECT @strUsername = @strUsername + ',' +username 
	FROM @tmpCust
	WHERE custid IS NULL
		OR isDeposit = 1
		
	IF @strUsername <> ''
	BEGIN			
		SELECT 100 ErrCode,STUFF(@strUsername,1,1,'') Username
		RETURN
	END
	
	--check unmarked problem accounts
	UPDATE t 
	SET isPA = 1
	FROM @tmpCust t
		INNER JOIN dbo.ProblemAccount pa WITH(NOLOCK) ON t.custid = pa.custid
	
	SELECT @strUsername = @strUsername + ',' +username 
	FROM @tmpCust
	WHERE custid IS NOT NULL
		AND isPA = 0
		AND isDeposit = 0
		
	IF @strUsername <> ''
	BEGIN
		SELECT 101 ErrCode,STUFF(@strUsername,1,1,'') Username
		RETURN
	END	

	--Not in the selected level
	SELECT @strUsername = @strUsername + ',' +username 
	FROM @tmpCust
	WHERE custid IS NOT NULL
		AND roleid <> @roleid
		
	IF @strUsername <> ''
	BEGIN
		SELECT 102 ErrCode,STUFF(@strUsername,1,1,'') Username
		RETURN
	END	
	
	DELETE pa 
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId	

	SELECT @SuccessAllDownlineList = ''

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
			EXEC dbo.Acc_CustomerInfo_Execrep_12
				@CustId = @CustId,
				@RoleId = @RoleId,
				@Action = 'UnmarkProblem',
				@ExcludeAbnormalMember = @ExcludeAbnormalMember,
				@ExcludeDirectMark = @ExcludeDirectMark, 
				@SuccessDownlineList = @SuccessDownlineList OUTPUT			
			
			SELECT @SuccessAllDownlineList = @SuccessAllDownlineList + ',' + CAST(@CustId AS VARCHAR(10)) + CASE WHEN @SuccessDownlineList <> '' THEN ',' ELSE '' END + @SuccessDownlineList 	
		END	
		ELSE 	
		BEGIN
			SELECT @SuccessAllDownlineList = @SuccessAllDownlineList + ',' + CAST(@CustId AS VARCHAR(10))
		END	

		SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

		-- Write log
		DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)
		IF @RoleId = 1
		BEGIN
			SELECT @ActionId = 31623
			SELECT  @LogDataNew = '<R'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'		
		END
		ELSE
		BEGIN
			SELECT @ActionId = 31619
			SELECT  @LogDataNew = '<R'
								+ ' Username="' + @UserName + '"'								
								+ ' ExcludeAbnormal="' + CAST (@ExcludeAbnormalMember AS VARCHAR(1)) + '"'
								+ ' ExcludeDirectMark="' + CAST (@ExcludeDirectMark AS VARCHAR(1)) + '"'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'		
		END

		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionId,
			@TrackingValue		= @LogDataNew,
			@Duration			= @Duration,
			@AffectedDownlines	= @SuccessDownlineList
	END	
	
	SELECT @SuccessAllDownlineList = STUFF(@SuccessAllDownlineList,1,1,'')
END
GO
