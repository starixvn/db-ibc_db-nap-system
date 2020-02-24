/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_LicenseeAccountReasonUpd
	@CustomerList	VARCHAR(MAX),
	@ActionId		TINYINT,
	@ReasonID		TINYINT,
	@Comment		NVARCHAR(600)='',

	@UserID			INT,
	@IP				VARCHAR(15),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: Johnson
	Date: 20200221
	Task : update preventive action & reason of problem account for deposit customer
	DB: DBCUST/CustDB

	Revisions:
		- 20200221@Johnson: Initial SP [Redmine:#128077]

	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT
	DECLARE @CustId INT, 
			@UserName NVARCHAR(50), 
			@Old_ActionName VARCHAR(100), 
			@Old_ReasonName VARCHAR(100),
			@Old_Comment NVARCHAR(600),
			@ActionName VARCHAR(100), 
			@ReasonName VARCHAR(100)
			
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, Comment NVARCHAR(600), ActionName VARCHAR(100), ReasonName VARCHAR(100), IsFinished BIT DEFAULT(0))

	SET	@startRun = GETDATE()

	INSERT INTO @tmpCust(Username, CustID)
	SELECT ci.Username, ci.custid
	FROM dbo.strSplit(@CustomerList, ',') f
		INNER JOIN dbo.customer ci WITH (NOLOCK) ON f.val = ci.username
		INNER JOIN Dep_CustSuper s WITH(NOLOCK) ON ci.srecommend = s.custid
	WHERE ci.roleid = 1
					
	SELECT @ErrMsg = STUFF((SELECT ', '+ l.Username
									FROM @tmpCust l
										LEFT JOIN @tmpCust c ON c.Username = l.Username
									WHERE c.CustId IS NULL
									FOR XML PATH('')),1,2,'')

	IF ISNULL(@ErrMsg,'') <> ''
    BEGIN
	   SELECT @ErrCode = 101, @ErrMsg = 'Invalid account(s): ' + @ErrMsg	   
	   RETURN
    END
	
	IF NOT EXISTS(SELECT 1 FROM ProblemAccountReasonAction WHERE ActionId = @ActionId AND ReasonID = @ReasonID)
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'The selected reason is not available for this preventive action.'
		RETURN
	END
	
	--get old ActionID & ReasonID
	UPDATE t 
	SET t.ReasonName = pr.ReasonName,
		t.ActionName = pa.ActionName,
		t.Comment = p.Comment
	FROM dbo.ProblemAccount p WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = p.CustId
		INNER JOIN ProblemAccountReason pr WITH(NOLOCK) ON p.ReasonID = pr.ReasonID
		INNER JOIN ProblemAccountAction pa WITH(NOLOCK) ON p.ActionID = pa.ActionID
		
	--update new Action & Reason
	UPDATE pa 
	SET pa.ActionID = @ActionID,
		pa.ReasonID = @ReasonID
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId	
	
	-- Write log
	DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)
	
	SELECT @ActionName = ActionName FROM ProblemAccountAction WITH(NOLOCK) WHERE ActionID = @ActionID
	SELECT @ReasonID = ReasonName FROM ProblemAccountReason WITH(NOLOCK) WHERE ReasonID = @ReasonID
		
	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
	
	WHILE (1=1)
	BEGIN		
		UPDATE TOP (1) @tmpCust
		SET isfinished = 1,
			@CustId = custid,
			@UserName = Username,
			@Old_ActionName = ActionName,
			@Old_ReasonName = ReasonName,
			@Old_comment = Comment
		WHERE isfinished = 0
				
		IF @@ROWCOUNT = 0 BREAK	

		SELECT  @LogDataOld = '<R'
						+ ' Username="' + @UserName + '"'
						+ ' Action="' + COALESCE(@Old_ActionName, SPACE(1)) + '"'
						+ ' Reason="' + COALESCE(@Old_ReasonName, SPACE(1)) + '"'
						+ ' Comment="' + COALESCE(@Old_Comment, SPACE(1)) + '"'
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
		
		SELECT  @LogDataNew = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' Action="' + COALESCE(@ActionName, SPACE(1)) + '"'
							+ ' Reason="' + COALESCE(@ReasonName, SPACE(1)) + '"'
							+ ' Comment="' + COALESCE(@Comment, SPACE(1)) + '"'
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
