/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE CS_ProblemAccount_RemoveCustomer
	@CustomerList				VARCHAR(MAX),
	@RoleId						TINYINT,
	@IsAllDownline				BIT,
	@IsConfirmed				BIT,

	@UserID						INT,
	@IP							VARCHAR(15),
	@ErrCode					INT = 0 OUTPUT,
	@ErrMsg						NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 20190808
	Task : Remove reduce BetLimit of problem account
	DB: DBCUST/CustDB

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]

	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT, @ActionId INT
	DECLARE @CustId INT, @UserName NVARCHAR(50), @DownlineList VARCHAR(MAX), @WarningList VARCHAR(MAX),
			@Old_MaxBet MONEY, @Old_MaxPerEvent MONEY, @SuccessDownlineList VARCHAR(MAX) = ''
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, MaxBet MONEY, MaxPerEvent MONEY, IsFinished BIT DEFAULT(0))
	DECLARE @tmpCustDownline TABLE (Username NVARCHAR(50), CustId INT, MaxBet MONEY, MaxPerEvent MONEY, IsFinished BIT DEFAULT(0))

	SET	@startRun = GETDATE()

	INSERT INTO @tmpCust(Username, CustID)
	SELECT ci.Username, ci.custid
	FROM dbo.f_StringSplit(@CustomerList, ',') f
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username
	OPTION (MAXRECURSION 0)

	UPDATE t 
	SET t.MaxBet = pa.MaxBet,
		t.MaxPerEvent = pa.MaxPerEvent
	FROM dbo.CS_ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId

	IF @IsConfirmed = 0
	BEGIN
		SELECT @WarningList= STUFF((SELECT ','+ t.Username
									FROM @tmpCust t
									WHERE t.MaxBet IS NULL
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
		WHERE t.MaxBet IS NULL
	END

	UPDATE pa 
	SET pa.MaxBet = NULL,
		pa.MaxPerEvent = NULL
	FROM dbo.CS_ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId

	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

	WHILE (1=1)
	BEGIN		
		UPDATE TOP (1) @tmpCust
		SET isfinished = 1,
			@CustId = custid,
			@UserName = Username,
			@Old_MaxBet = MaxBet,
			@Old_MaxPerEvent = MaxPerEvent
		WHERE isfinished = 0
	
		IF @@ROWCOUNT = 0 BREAK	
		
		IF @RoleId <> 1 AND @IsAllDownline = 1
		BEGIN
			EXEC dbo.CS_DynamicCustSetting_01
				@CustId = @CustId,
				@RoleId = @RoleId,
				@Action = 'RemoveReduceBetLimit',
				@SuccessDownlineList = @SuccessDownlineList OUTPUT
		END

		-- Write log
		DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)
		IF @RoleId = 1
		BEGIN
			SELECT @ActionId = 31604
			SELECT  @LogDataOld = '<R'
								+ ' MPM="' + dbo.f_CS_FomatNumber (CAST (@Old_MaxPerEvent AS VARCHAR(50))) + '"'
								+ ' Max="' + dbo.f_CS_FomatNumber (CAST (@Old_MaxBet AS VARCHAR(50))) + '"'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'

			SELECT  @LogDataNew = '<R'
								+ ' MPM="NULL"'
								+ ' Max="NULL"'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'		
		END
		ELSE
		BEGIN
			SELECT @ActionId = 31603
			SELECT  @LogDataOld = '<R'
								+ ' Username="' + @UserName + '"'								
								+ ' MPM="' + dbo.f_CS_FomatNumber (CAST (@Old_MaxPerEvent AS VARCHAR(50))) + '"'
								+ ' Max="' + dbo.f_CS_FomatNumber (CAST (@Old_MaxBet AS VARCHAR(50))) + '"'
								+ ' AllDownline="' + CAST (@IsAllDownline AS VARCHAR(1)) + '"'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'

			SELECT  @LogDataNew = '<R'
								+ ' Username="' + @UserName + '"'								
								+ ' MPM="NULL"'
								+ ' Max="NULL"'
								+ ' AllDownline="' + CAST (@IsAllDownline AS VARCHAR(1)) + '"'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'		
		END

		EXEC dbo.CS_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionId,
			@TrackingValue		= @LogDataNew,
			@TrackingValue2		= @LogDataOld,
			@Duration			= @Duration,
			@AffectedDownlines	= @SuccessDownlineList
	END	
END
GO
