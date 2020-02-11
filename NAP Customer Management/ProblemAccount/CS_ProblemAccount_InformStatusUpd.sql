/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE CS_ProblemAccount_InformStatusUpd
	@customerList 	VARCHAR(MAX),
	@roleid 		TINYINT,
	@isApplyDownlines BIT = 0,
	@InformedType 	TINYINT = 0,
	@UserID 		INT,
	@IP				VARCHAR(15),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: Johnson
	Date: 20191231
	Task : update inform status
	DB: DBCUST/CustDB

	Revisions:
		- 20191231@Johnson: Initial SP [Redmine:#121298]
		
	Parameter's explaination: 
		- @InformedType = 0: none week, 1: 1st week, 2: 2nd week, 3: both week
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, 
			@duration INT,
			@CustId INT,
			@WrongUserName VARCHAR(MAX)
			
	DECLARE @tmpCust TABLE (Username VARCHAR(30), CustId INT, RoleId TINYINT, isExists BIT DEFAULT(0), isFinished BIT DEFAULT(0), isLog BIT DEFAULT(0))
	
	INSERT INTO @tmpCust(Username)
	SELECT Val
	FROM dbo.f_StringSplit(@CustomerList, ',') f
	
	UPDATE t
	SET t.custid = c.custid,
		t.roleid = c.roleid
	FROM @tmpCust t
		INNER JOIN customer c WITH(NOLOCK) ON t.username = c.username
	WHERE c.site = 'CN88'
	
	UPDATE t
	SET t.isExists = 1		
	FROM @tmpCust t
		INNER JOIN CS_ProblemAccount c WITH(NOLOCK) ON t.custid = c.custid
		
	SELECT @WrongUserName = STUFF((SELECT ', '+ Username
									FROM @tmpCust 										
									WHERE CustId IS NULL
									FOR XML PATH('')),1,2,'')

	IF ISNULL(@WrongUserName,'') <> ''
    BEGIN
	   SELECT @ErrCode = 101, @ErrMsg = 'Invalid account(s): ' + @WrongUserName	   
	   RETURN
    END	
	
	SELECT @WrongUserName = STUFF((SELECT ', '+ Username
									FROM @tmpCust 										
									WHERE roleid <> @roleid
									FOR XML PATH('')),1,2,'')

	IF ISNULL(@WrongUserName,'') <> ''
    BEGIN
	   SELECT @ErrCode = 102, @ErrMsg = 'Account(s) not in the selected level: ' + @WrongUserName  
	   RETURN
    END
	
	SELECT @WrongUserName = STUFF((SELECT ', '+ Username
									FROM @tmpCust 										
									WHERE isExists = 0
									FOR XML PATH('')),1,2,'')

	IF ISNULL(@WrongUserName,'') <> ''
    BEGIN
	   SELECT @ErrCode = 103, @ErrMsg = 'Account(s) not in the problem account list: ' + @WrongUserName	   
	   RETURN
    END	
	
	UPDATE cs
	SET Informed1By = CASE WHEN @InformedType IN (1,3) THEN @UserID 	
							WHEN @InformedType = 0 THEN NULL ELSE Informed1By END,
		Informed2By = CASE WHEN @InformedType IN (2,3) THEN @UserID 
							WHEN @InformedType = 0 THEN NULL ELSE Informed2By END							
	FROM dbo.CS_ProblemAccount cs WITH(UPDLOCK,ROWLOCK)
	WHERE custid IN (SELECT custid FROM @tmpCust)
	
	IF @isApplyDownlines = 1 AND @roleid >= 2
	BEGIN
		WHILE (1=1)
		BEGIN		
			UPDATE TOP (1) @tmpCust
			SET isfinished = 1,
				@CustId = custid			
			WHERE isfinished = 0
		
			IF @@ROWCOUNT = 0 BREAK	

			EXEC dbo.CS_DynamicCustomerInfo_02
				@CustId	= @CustId,		
				@roleid	= @roleid,
				@InformedType = @InformedType,
				@InformedBy	= @UserID,
				@Action	= 'UpdateInformStatus'
		END		
	END
	
	DECLARE @LogData VARCHAR(MAX)
	
	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())	
	
	--write log 
	WHILE(1=1)
	BEGIN
		UPDATE TOP (1) @tmpCust
		SET isLog = 1,
			@CustId = custid			
		WHERE isLog = 0
		
		IF @@ROWCOUNT = 0 
			BREAK;
			
		SELECT  @LogData = '<R'
							+ ' Action="' + CASE @InformedType WHEN 0 THEN 'None week'
												WHEN 1 THEN '1st week' 
												WHEN 2 THEN '2nd week' 
												WHEN 3 THEN 'Both weeks' END+ '"'
							+ ' ApplyDownlines="' +  COALESCE(CAST(@isApplyDownlines AS VARCHAR(10)), SPACE(1)) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'		

		EXEC dbo.CS_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31612,
			@TrackingValue		= @LogData,			
			@Duration			= @Duration
	END
END	
GO