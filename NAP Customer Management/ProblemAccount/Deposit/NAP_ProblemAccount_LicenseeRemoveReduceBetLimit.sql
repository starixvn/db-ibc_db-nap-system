/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_LicenseeRemoveReduceBetLimit
	@CustomerList	VARCHAR(MAX),	
	@IsConfirmed	BIT,

	@UserID			INT,
	@IP				VARCHAR(15),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: Johnson
	Date: 20200219
	Task : Remove reduce BetLimit of problem account for deposit customer
	DB: DBCUST/CustDB

	Revisions:
		- 20200219@Johnson: Initial SP [Redmine:#128077]
		- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 

	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT
	DECLARE @CustId INT, @UserName NVARCHAR(50), @WarningList VARCHAR(MAX),
			@Old_MaxBet MONEY, @Old_MaxPerEvent MONEY, @LogDataNew VARCHAR(500)
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, MaxBet MONEY, MaxPerEvent MONEY, IsFinished BIT DEFAULT(0))
	
	SET	@startRun = GETDATE()

	INSERT INTO @tmpCust(Username, CustID)
	SELECT ci.Username, ci.custid
	FROM STRING_SPLIT(@CustomerList, ',') f
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON f.value = ci.username
	WHERE srecommend IN (SELECT custid FROM Dep_CustSuper s WITH(NOLOCK))
		AND ci.roleid = 1
	
	--get old bet limit
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
			SELECT @ErrCode = 102, @ErrMsg = 'There is no account with reduced bet limit to be removed. No action has been done.' 
			RETURN
		END
    END
	ELSE
	BEGIN
		DELETE t 
		FROM @tmpCust t
		WHERE t.MaxBet IS NULL
	END
	
	--update to reduce betlimit
	UPDATE pa 
	SET pa.MaxBet = NULL,
		pa.MaxPerEvent = NULL
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
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
			AND CustID IS NOT NULL
	
		IF @@ROWCOUNT = 0 BREAK	

		-- Write log				
		SELECT  @LogDataNew = '<R'
							+ ' MaxPerMatch="' + dbo.f_FomatNumber (CAST (@Old_MaxPerEvent AS VARCHAR(50))) + '"'
							+ ' MaxBet="' + dbo.f_FomatNumber (CAST (@Old_MaxBet AS VARCHAR(50))) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'				
		
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31630,
			@TrackingValue		= @LogDataNew,
			@Duration			= @Duration
	END	
END
GO
