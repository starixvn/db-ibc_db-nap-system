/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_ClosedAccount
	@CustomerList	VARCHAR(MAX),
	@RoleId			TINYINT,
	@IsConfirmed	BIT,

	@UserID			INT,
	@IP				VARCHAR(15),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(MAX) = '' OUTPUT	
AS
/*  
	Created: Elodie
	Date: 20200210
	Task : Closed problem account
	DB: DBCUST/CustDB

	Revisions:
		- 20200210@Elodie: Initial SP [Redmine:#127446]

	Parameter's explaination:
*/

BEGIN
	SET NOCOUNT ON
	DECLARE @StartRun DATETIME, @Duration INT
	DECLARE @CustId INT, @UserName NVARCHAR(50), @OldStatusID TINYINT, @AffectedList VARCHAR(MAX), @WarningList VARCHAR(MAX)
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, StatusID TINYINT, IsFinished BIT DEFAULT(0))

	SELECT  @StartRun = GETDATE()			

	INSERT INTO @tmpCust(Username, CustID, StatusID)
	SELECT ci.Username, ci.custid,
		CASE WHEN ci.Enabled = 1 THEN CASE WHEN ci.closed = 1 THEN 3 WHEN ci.reject = 1 THEN 2 ELSE 1 END ELSE 4 END AS CustStatus
	FROM dbo.f_StringSplit(@CustomerList, ',') f
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username
	
	IF @IsConfirmed = 0
	BEGIN
		IF EXISTS (SELECT 1 FROM @tmpCust t WHERE t.StatusID <> 3)
		BEGIN
			SELECT @WarningList= STUFF((SELECT ', '+ t.Username
										FROM @tmpCust t
										WHERE t.StatusID = 3
										FOR XML PATH('')),1,2,'')

			IF ISNULL(@WarningList,'') <> '' 
			BEGIN
				SELECT @ErrCode = 101, @ErrMsg = @WarningList
				RETURN
			END
		END
		ELSE
		BEGIN	
			SELECT @ErrCode = 102, @ErrMsg = '' --All accounts are closed, return
			RETURN
		END
	END
	ELSE
	BEGIN
		DELETE t 
		FROM @tmpCust t
		WHERE StatusID = 3
	END

	WHILE (1=1)
	BEGIN		
		UPDATE TOP (1) @tmpCust
		SET isfinished = 1,
			@CustId = custid,
			@UserName = Username,
			@OldStatusID = StatusID
		WHERE isfinished = 0
	
		IF @@ROWCOUNT = 0 BREAK	

		IF @RoleID BETWEEN 2 AND 4
		BEGIN
			EXEC Acc_CustomerInfo_Execrep_04
				 @CustID		= @CustID
				,@RoleID		= @RoleID
				,@Action		= 'Closed'
				,@Closed		= 1
				,@SystemID		= 1
		END	
		ELSE
		BEGIN
			UPDATE custinfo WITH(ROWLOCK, UPDLOCK) 
			SET Closed = 1
			WHERE custid = @custid

			IF NOT EXISTS (SELECT 1 FROM dbo.CustLoginInfo_Member WITH(NOLOCK) WHERE custid = @custid)
			BEGIN
				INSERT INTO [CustLoginInfo_Member]([CustID],[SecurityCode],[IP],[LastChangedID],[LastChangedDate],ClosedReason)
				VALUES(@custid,NULL,@IP,@UserID,GETDATE(),1)
			END
			ELSE
			BEGIN
				UPDATE [dbo].CustLoginInfo_Member WITH (ROWLOCK, UPDLOCK) set ClosedReason = 1
				WHERE custid = @custid
			END
		END	

		SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

		-- Write log
		DECLARE @LogDataNew VARCHAR(500)
		SELECT  @LogDataNew = '<R'
								+ ' Username="' + @UserName + '"'								
								+ ' OldStatus="' + COALESCE(CASE @OldStatusID WHEN 1 THEN 'Open' WHEN 2 THEN 'Suspended' WHEN 3 THEN 'Closed' WHEN 4 THEN 'Disabled' END, SPACE(1)) + '"'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'		
	
		--EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		--	@UserId				= @UserId,
		--	@CustId				= @CustId,
		--	@ActionId			= 1172,
		--	@TrackingValue		= @LogDataNew,
		--	@Duration			= @Duration,
		--	@AffectedDownlines	= @AffectedList
	END
END
GO