/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CS_ProblemAccount_InactiveAccount]	
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
	Date: 20190808
	Task : Inactive problem account
	DB: DBCUST/CustDB

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]

	Parameter's explaination:
*/

BEGIN
	SET NOCOUNT ON
	DECLARE @StartRun DATETIME, @Duration INT
	DECLARE @CustId INT, @UserName NVARCHAR(50), @OldStatusID TINYINT, @AffectedList VARCHAR(MAX), @WarningList VARCHAR(MAX)
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, StatusID TINYINT, IsFinished BIT DEFAULT(0))

	SELECT  @StartRun = GETDATE()			

	INSERT INTO @tmpCust(Username, CustID)
	SELECT ci.Username, ci.custid
	FROM dbo.f_StringSplit(@CustomerList, ',') f
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username

	UPDATE t 
	SET t.StatusID = f.CustStatus
	FROM @tmpCust t 
		CROSS APPLY dbo.f_CS_GetCustomerStatus(t.CustId) f

	IF @IsConfirmed = 0
	BEGIN
		SELECT @WarningList= STUFF((SELECT ','+ t.Username
									FROM @tmpCust t
									WHERE t.StatusID = 1
									FOR XML PATH('')),1,1,'')

		IF ISNULL(@WarningList,'') <> '' 
		BEGIN
			SELECT @ErrCode = 101, @ErrMsg = @WarningList
			RETURN
		END
	END
	ELSE
	BEGIN
		DELETE t 
		FROM @tmpCust t
		WHERE StatusID = 1
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

		EXEC dbo.CS_DynamicCustomerInfo_01
			@CustId			= @CustId,
			@RoleId			= @RoleId,
			@Action			= 'UpdateStatus',
			@Mode			= 1,
			@AffectedList	= @AffectedList OUTPUT

		SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

		-- Write log
		DECLARE @LogDataNew VARCHAR(500)
		SELECT  @LogDataNew = '<R'
								+ ' Username="' + @UserName + '"'								
								+ ' OldStatus="' + COALESCE(CASE @OldStatusID WHEN 1 THEN 'Inactive' WHEN 2 THEN 'Suspended' WHEN 3 THEN 'ViewOnly' WHEN 4 THEN 'Active' END, SPACE(1)) + '"'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'		
	
		EXEC dbo.CS_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31605,
			@TrackingValue		= @LogDataNew,
			@Duration			= @Duration,
			@AffectedDownlines	= @AffectedList
	END
END
GO