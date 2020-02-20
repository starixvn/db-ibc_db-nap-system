/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_ProblemAccount_LicenseeRemoveCustomer]
	@CustomerList VARCHAR(MAX),

	@UserID		INT,
	@IP			VARCHAR(15),
	@ErrCode 	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20200219@Johnson	
	Task : Unmark problem account for deposit customer
	DB: DBCUST/CustDB

	Revisions:
		- 20200219@Johnson: Initial SP [Redmine:#128077]
		
	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE	@startRun DATETIME, @duration INT
	DECLARE @CustId INT
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, IsFinished BIT DEFAULT(0))

	SET	@startRun = GETDATE()

	INSERT INTO @tmpCust(Username, CustID)
	SELECT ci.Username, ci.custid
	FROM dbo.strSplit(@CustomerList, ',') f
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username
	WHERE srecommend IN (SELECT custid FROM Dep_CustSuper)
		AND roleid = 1
	
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
	END	
END
GO
