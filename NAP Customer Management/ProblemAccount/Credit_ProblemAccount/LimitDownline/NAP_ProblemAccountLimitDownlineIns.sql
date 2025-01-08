/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_ProblemAccountLimitDownlineIns]
	@CustomerList VARCHAR(MAX),
	
	@UserID		INT,
	@IP			VARCHAR(15),
	@ErrCode 	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(MAX) = '' OUTPUT,
	@cntMember  INT = 0 OUTPUT
AS
/*
	Created: 20210301@Johnson
	Task : add problem account limit downline config for credit site
	DB: DBCUST/CustDB

	Revisions:
		- 20210301@Johnson: Initial SP [Redmine:#149477]	
		- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831]
		- 20240807@Helios: Scale Out DBCUST - Apply Inhouse replication for tables of problem account [Redmine:#209747] 
	Parameter's explaination: 		
		- cntMember: number of SMA add successfully
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, 
			@duration INT,
			@CustId INT,
			@username VARCHAR(30),
			@WrongUserName VARCHAR(MAX)

	SET	@startRun = GETDATE()
	
	DECLARE @tmpUsername TABLE (Username VARCHAR(MAX))	
	DECLARE @tmpCust TABLE (Username VARCHAR(30), CustId INT, currency INT, RoleId TINYINT, isExists BIT DEFAULT(0), IsLog BIT DEFAULT(0))	

	INSERT INTO @tmpUsername(Username)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@CustomerList, ',') f
	WHERE value <> ''

	INSERT INTO @tmpCust(Username, CustID, RoleId)
	SELECT c.Username, c.custid, c.roleid
	FROM @tmpUsername t
		INNER JOIN dbo.customer c WITH (NOLOCK) ON t.Username = c.username		
	WHERE c.site <> 'CN88' 
		AND NOT EXISTS (SELECT custid FROM dbo.Dep_CustSuper WITH (NOLOCK) WHERE custid = c.srecommend)
	
	----START: Validattion-------------------------------------------------
	SELECT @WrongUserName = STUFF((SELECT ', '+ l.Username
									FROM @tmpUsername l
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
									WHERE RoleId NOT IN (2,3,4)
									FOR XML PATH('')),1,2,'')

	IF ISNULL(@WrongUserName,'') <> ''
    BEGIN
	   SELECT @ErrCode = 102, @ErrMsg = 'Not Super, Master or Agent account(s): ' + @WrongUserName	   
	   RETURN
    END	
	
	UPDATE t 
	SET isExists = 1
	FROM @tmpCust t
		INNER JOIN ProblemAccountLimitDownline p WITH(NOLOCK) ON t.custid = p.custid
	
	--500 accounts per request, no need execrep
	INSERT INTO ProblemAccountLimitDownline(CustID,UserID,CreatedDate,RepUpdateTime)
	SELECT custid, @userid, GETDATE(), dbo.f_GetDateTime2()
	FROM @tmpCust t
	WHERE isExists = 0
	
	SELECT @cntMember =@@ROWCOUNT
	
	-- Write log
	DECLARE @LogDataNew VARCHAR(500)
	SELECT  @LogDataNew = '<R IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
		
	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) @tmpCust
		SET @CustId = custid,
			@UserName = UserName,
			IsLog = 1
		WHERE isLog = 0
			AND isExists = 0
	
		IF @@ROWCOUNT = 0 BREAK
		
		SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31637,
			@TrackingValue		= @LogDataNew,
			@Duration			= @Duration
	END
END	