/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE CS_ProblemAccount_RemoveReduceBetLimit
	@CustomerList	VARCHAR(MAX),
	@RoleId			TINYINT,
	@MaxBet			MONEY,
	@MaxPerEvent	MONEY,

	@UserID			INT,
	@IP				NVARCHAR(50),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 20190808
	Task : Reduce BetLimit of problem account
	DB: DBCUST/CustDB

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]

	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @endRun	DATETIME, @duration	INT
	DECLARE @CustId INT, @UserName NVARCHAR(50), @DownlineList VARCHAR(MAX), @IsReduce BIT, @Old_MaxBet MONEY, @Old_MaxPerEvent MONEY
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, IsReduce BIT, MaxBet MONEY, MaxPerEvent MONEY, IsFinished BIT DEFAULT(0))

	SET	@startRun = GETDATE()

	INSERT INTO @tmpCust(Username, CustID)
	SELECT ci.Username, ci.custid
	FROM dbo.f_StringSplit(@CustomerList, ',') f
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON f.val = ci.username

	UPDATE t 
	SET t.IsReduce = pa.IsReducedBetLimit,
		t.MaxBet = pa.MaxBet,
		t.MaxPerEvent = pa.MaxPerEvent
	FROM dbo.CS_ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId

	UPDATE pa 
	SET pa.MaxBet = @MaxBet,
		pa.MaxPerEvent = @MaxPerEvent,
		pa.IsReducedBetLimit = 1
	FROM dbo.CS_ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId

	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

	WHILE (1=1)
	BEGIN		
		UPDATE TOP (1) @tmpCust
		SET isfinished = 1,
			@CustId = custid,
			@UserName = Username,
			@IsReduce = IsReduce,
			@Old_MaxBet = MaxBet,
			@Old_MaxPerEvent = MaxPerEvent
		WHERE isfinished = 0
	
		IF @@ROWCOUNT = 0 BREAK	

		IF @RoleId <> 1
		BEGIN
			EXEC dbo.CS_DynamicCustomerInfo_02
				@CustId = @CustId,
				@RoleId = @RoleId,
				@Action = 'ReduceBetLimit'
		END

		-- Write log
		DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)
		IF @IsReduce = 1
		BEGIN
			SELECT  @LogDataOld = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' MPM="' + dbo.f_CS_FomatNumber (CAST (@Old_MaxPerEvent AS VARCHAR(50))) + '"'
							+ ' Max="' + dbo.f_CS_FomatNumber (CAST (@Old_MaxBet AS VARCHAR(50))) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'
		END

		SELECT  @LogDataNew = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' MPM="' + dbo.f_CS_FomatNumber (CAST (@MaxPerEvent AS VARCHAR(50))) + '"'
							+ ' Max="' + dbo.f_CS_FomatNumber (CAST (@MaxBet AS VARCHAR(50))) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'
	
		IF @RoleId = 4
		BEGIN
			SELECT @DownlineList = STUFF((SELECT ','+ CAST(c.CustID AS VARCHAR(20))
										FROM dbo.custInfo c
										WHERE c.srecommend = @CustId AND c.custid <> @CustId
										FOR XML PATH('')),1,1,'')
		END
		ELSE IF @RoleId = 3
		BEGIN
			SELECT @DownlineList = STUFF((SELECT ','+ CAST(c.CustID AS VARCHAR(20))
										FROM dbo.custInfo c
										WHERE c.mrecommend = @CustId AND c.custid <> @CustId
										FOR XML PATH('')),1,1,'')
		END
		ELSE IF @RoleId = 2
		BEGIN
			SELECT @DownlineList = STUFF((SELECT ','+ CAST(c.CustID AS VARCHAR(20))
										FROM dbo.custInfo c
										WHERE c.recommend = @CustId AND c.custid <> @CustId
										FOR XML PATH('')),1,1,'')
		END

		EXEC dbo.CS_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31602,
			@TrackingValue		= @LogDataNew,
			@TrackingValue2		= @LogDataOld,
			@Duration			= @Duration,
			@AffectedDownlines	= @DownlineList
	END	
END
GO
