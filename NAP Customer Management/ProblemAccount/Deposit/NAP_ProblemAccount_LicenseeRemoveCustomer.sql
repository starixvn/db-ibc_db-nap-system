/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_ProblemAccount_LicenseeRemoveCustomer]
	@CustomerList				VARCHAR(MAX),

	@UserID						INT,
	@IP							VARCHAR(15),
	@SuccessAllDownlineList		VARCHAR(MAX) = '' OUTPUT,
	@ErrCode 					INT = 0 OUTPUT,
	@ErrMsg						NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20200219@Johnson	
	Task : Unmark problem account for deposit customer
	DB: DBCUST/CustDB

	Revisions:
		- 20200219@Johnson: Initial SP [Redmine:#128077]
		- 20201016@Elodie: Output all cust list is removed PA [Redmine:#141756]
		- 20201215@Johnson: check & output result status when unmark PA for member level [redmine:#146400]
	Parameter's explaination: 
		* 100: invalid accounts
		* 101: unmarked problem accounts
		* 102: Non-Member Accounts
	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE	@startRun DATETIME, @duration INT
	DECLARE @CustId INT
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, roleid TINYINT, isPA BIT DEFAULT 0, isDeposit BIT, IsFinished BIT DEFAULT(0))	
	DECLARE @strUsername VARCHAR(MAX) = ''
	
	SET	@startRun = GETDATE()

	INSERT INTO @tmpCust(Username, CustID,roleid,isDeposit)
	SELECT DISTINCT f.val, ci.custid, ci.roleid, CASE WHEN s.custid IS NOT NULL THEN 1 ELSE 0 END
	FROM dbo.strSplit(@CustomerList, ',') f
		LEFT JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username
		LEFT JOIN Dep_CustSuper s WITH(NOLOCK) ON ci.srecommend = s.custid
		
	SELECT @strUsername = ''
		
	--check invalid accounts	
	SELECT @strUsername = @strUsername + ',' +username 
	FROM @tmpCust
	WHERE custid IS NULL
		OR isDeposit = 0
		
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
		
	IF @strUsername <> ''
	BEGIN
		SELECT 101 ErrCode,STUFF(@strUsername,1,1,'') Username
		RETURN
	END	

	--Non-Member Accounts
	SELECT @strUsername = @strUsername + ',' +username 
	FROM @tmpCust
	WHERE custid IS NOT NULL
		AND roleid <> 1
		
	IF @strUsername <> ''
	BEGIN
		SELECT 102 ErrCode,STUFF(@strUsername,1,1,'') Username
		RETURN
	END
	
	DELETE pa 
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId	
	
	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
	
	-- Write log
	DECLARE @LogData VARCHAR(500)
	SELECT  @LogData = '<R'
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'	
								
	WHILE (1=1)
	BEGIN		
		UPDATE TOP (1) @tmpCust
		SET isfinished = 1,
			@CustId = custid
		WHERE isfinished = 0
			AND custid IS NOT NULL
	
		IF @@ROWCOUNT = 0 BREAK	
		
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31627,
			@TrackingValue		= @LogData,
			@Duration			= @Duration		
			
		SELECT @SuccessAllDownlineList = @SuccessAllDownlineList + ',' + CAST(@CustId AS VARCHAR(10))	
	END	

	SELECT @SuccessAllDownlineList = STUFF(@SuccessAllDownlineList,1,1,'')
END
GO
