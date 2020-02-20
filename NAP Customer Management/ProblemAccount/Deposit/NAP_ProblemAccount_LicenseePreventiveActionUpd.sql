/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_LicenseePreventiveActionUpd
	@CustomerList 	VARCHAR(MAX),	
	@ActionID		TINYINT,
	
	@UserID 		INT,
	@IP				VARCHAR(15) = '',
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
AS
	/*
		Created: 20200213@Johnson
		Task: Problem Account - Licensee VIP player 
		DB: DBCUST/CUSTDB
		
		Revisions:
			- 20200219@Johnson: initial sp [redmine:#128077]
			
		Paramter's Explanations:	
			
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
		
	DECLARE @tmpCust TABLE(custid INT, username VARCHAR(50), ActionID TINYINT, isfinished BIT DEFAULT 0)
	DECLARE @CustId INT
	
	SET @startRun = GETDATE()
	
	INSERT INTO @tmpCust(Username, CustID)
	SELECT ci.Username, ci.custid
	FROM dbo.strSplit(@CustomerList, ',') f
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username
	WHERE srecommend IN (SELECT custid FROM Dep_CustSuper s WITH(NOLOCK))
		AND ci.roleid = 1
		
	--get old ActionID	
	UPDATE t 
	SET t.ActionID = pa.ActionID
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId
	
	DELETE @tmpCust WHERE ActionID = @ActionID OR custid IS NULL
	
	--update new actionID
	UPDATE pa 
	SET pa.ActionID = @ActionID		
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId	
	
	-- Write log
	DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500),
			@ActionName_Old VARCHAR(100), @ActionName VARCHAR(100)
	
	SELECT @ActionName = ActionName
	FROM ProblemAccountAction WITH(NOLOCK)
	WHERE ActionID = @ActionID
	
	SELECT  @LogDataNew = '<R'							
							+ ' Action="' + COALESCE(@ActionName, SPACE(1)) + '"'							
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'
							
	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
								
	WHILE (1=1)
	BEGIN		
		UPDATE TOP (1) t
		SET isfinished = 1,
			@CustId = custid,			
			@ActionName_Old = p.ActionName
		FROM @tmpCust t
			INNER JOIN ProblemAccountAction p WITH(NOLOCK) ON t.ActionID = p.ActionID
		WHERE isfinished = 0			
	
		IF @@ROWCOUNT = 0 BREAK	

		SELECT  @LogDataOld = '<R'							
						+ ' Action="' + COALESCE(@ActionName_Old, SPACE(1)) + '"'							
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
							
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31631,
			@TrackingValue		= @LogDataNew,
			@TrackingValue2		= @LogDataOld,
			@Duration			= @Duration
	END	
END	
GO