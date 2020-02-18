/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_RemoveReduceBetLimit
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
	Date: 20200210
	Task : Remove reduce BetLimit of problem account for credit site
	DB: DBCUST/CustDB

	Revisions:
		- 20200210@Elodie: Initial SP [Redmine:#127446]

	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT, @ActionId INT
	DECLARE @CustId INT, @UserName NVARCHAR(50), @WarningList VARCHAR(MAX),
			@Old_MaxBet MONEY, @Old_MaxPerEvent MONEY, @SuccessDownlineList VARCHAR(MAX) = '', @LogDataNew VARCHAR(500)
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, MaxBet MONEY, MaxPerEvent MONEY, IsFinished BIT DEFAULT(0))
	DECLARE @tmpCustDownline TABLE (CustId INT, UplineName NVARCHAR(50), MaxBet MONEY, MaxPerEvent MONEY, IsFinished BIT DEFAULT(0))

	SET	@startRun = GETDATE()

	INSERT INTO @tmpCust(Username, CustID)
	SELECT ci.Username, ci.custid
	FROM dbo.f_StringSplit(@CustomerList, ',') f
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username
	OPTION (MAXRECURSION 0)

	UPDATE t 
	SET t.MaxBet = pa.MaxBet,
		t.MaxPerEvent = pa.MaxPerEvent
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId

	IF @IsConfirmed = 0
	BEGIN
		IF EXISTS (SELECT 1 FROM @tmpCust t WHERE MaxBet IS NOT NULL)
		BEGIN
			SELECT @WarningList= STUFF((SELECT ', '+ t.Username
										FROM @tmpCust t
										WHERE t.MaxBet IS NULL
										FOR XML PATH('')),1,2,'')

			IF ISNULL(@WarningList,'') <> '' 
			BEGIN
			   SELECT @ErrCode = 101, @ErrMsg = @WarningList
			   RETURN
			END
		END
		ELSE
		BEGIN	
			SELECT @ErrCode = 102, @ErrMsg = '' --All accounts don't reduce BL yet, return
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
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId

	IF @IsAllDownline = 1 AND @RoleId <> 1
	BEGIN
		IF @RoleId = 4
		BEGIN
			INSERT INTO @tmpCustDownline(CustID, UplineName, MaxBet, MaxPerEvent)
			SELECT ci.custid, t.Username, pa.MaxBet, pa.MaxPerEvent
			FROM @tmpCust t				
				INNER JOIN dbo.custInfo c WITH (NOLOCK) ON t.CustId = c.custid		
				INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON t.CustId = ci.srecommend
				INNER JOIN dbo.ProblemAccount pa WITH (NOLOCK) ON pa.CustId = ci.custid
			WHERE pa.MaxBet IS NOT NULL
		END
		ELSE IF @RoleId = 3
		BEGIN
			INSERT INTO @tmpCustDownline(CustID, UplineName, MaxBet, MaxPerEvent)
			SELECT ci.custid, t.Username, pa.MaxBet, pa.MaxPerEvent
			FROM @tmpCust t				
				INNER JOIN dbo.custInfo c WITH (NOLOCK) ON t.CustId = c.custid	
				INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON t.CustId = ci.mrecommend
				INNER JOIN dbo.ProblemAccount pa WITH (NOLOCK) ON pa.CustId = ci.custid
			WHERE pa.MaxBet IS NOT NULL
		END
		ELSE IF @RoleId = 2
		BEGIN
			INSERT INTO @tmpCustDownline(CustID, UplineName, MaxBet, MaxPerEvent)
			SELECT ci.custid, t.Username, pa.MaxBet, pa.MaxPerEvent
			FROM @tmpCust t				
				INNER JOIN dbo.custInfo c WITH (NOLOCK) ON t.CustId = c.custid
				INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON t.CustId = ci.recommend
				INNER JOIN dbo.ProblemAccount pa WITH (NOLOCK) ON pa.CustId = ci.custid
			WHERE pa.MaxBet IS NOT NULL
		END

		UPDATE pa 
		SET pa.MaxBet = NULL,
			pa.MaxPerEvent = NULL
		FROM dbo.ProblemAccount pa WITH (ROWLOCK)
			INNER JOIN @tmpCustDownline t ON t.CustId = pa.CustId
	END

	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())	

	SELECT @ActionId = CASE WHEN @RoleId = 1 THEN 31616 ELSE 31615 END

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

		-- Write log		
		IF @RoleId = 1
		BEGIN
			SELECT  @LogDataNew = '<R'
								+ ' MPE="' + dbo.f_CS_FomatNumber (CAST (@Old_MaxPerEvent AS VARCHAR(50))) + '"'
								+ ' Max="' + dbo.f_CS_FomatNumber (CAST (@Old_MaxBet AS VARCHAR(50))) + '"'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'				
		END
		ELSE
		BEGIN
			SELECT  @LogDataNew = '<R'
								+ ' Username="' + @UserName + '"'								
								+ ' MPE="' + dbo.f_CS_FomatNumber (CAST (@Old_MaxPerEvent AS VARCHAR(50))) + '"'
								+ ' Max="' + dbo.f_CS_FomatNumber (CAST (@Old_MaxBet AS VARCHAR(50))) + '"'
								+ ' AllDownline="' + CAST (@IsAllDownline AS VARCHAR(1)) + '"'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'			
		END

		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionId,
			@TrackingValue		= @LogDataNew,
			@Duration			= @Duration
	END	

	SELECT @ActionId = 31618
	WHILE (1=1)
	BEGIN		
		UPDATE TOP (1) @tmpCustDownline
		SET isfinished = 1,
			@CustId = custid,
			@UserName = UplineName,
			@Old_MaxBet = MaxBet,
			@Old_MaxPerEvent = MaxPerEvent
		WHERE isfinished = 0
	
		IF @@ROWCOUNT = 0 BREAK	

		-- Write log
		
		SELECT  @LogDataNew = '<R'
							+ ' Upline="' + @UserName + '"'								
							+ ' MPM="' + dbo.f_FomatNumber (CAST (@Old_MaxPerEvent AS VARCHAR(50))) + '"'
							+ ' Max="' + dbo.f_FomatNumber (CAST (@Old_MaxBet AS VARCHAR(50))) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'			

		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionId,
			@TrackingValue		= @LogDataNew,
			@Duration			= @Duration
	END	
END
GO
