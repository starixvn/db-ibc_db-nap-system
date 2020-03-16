/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_LicenseeReduceBetLimit
	@CustomerList	VARCHAR(MAX),
	@MaxBet			MONEY,
	@MaxPerMatch	MONEY,

	@UserID			INT,
	@IP				VARCHAR(15),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: Johnson
	Date: 20200219
	Task : Reduce BetLimit of problem account for deposit customer
	DB: DBCUST/CustDB

	Revisions:
		- 20200219@Johnson: Initial SP [Redmine:#128077]

	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT
	DECLARE @CustId INT, @UserName NVARCHAR(50), @Old_MaxBet MONEY, @Old_MaxPerEvent MONEY
	DECLARE @tmpCust TABLE (Username NVARCHAR(50), CustId INT, isVip BIT, site VARCHAR(50), MaxBet MONEY, MaxPerEvent MONEY, IsFinished BIT DEFAULT(0))

	SET	@startRun = GETDATE()

	INSERT INTO @tmpCust(Username, CustID, site, isVip)
	SELECT ci.Username, ci.custid,s.site, CASE WHEN cv.custid IS NULL THEN 0 ELSE 1 END
	FROM dbo.strSplit(@CustomerList, ',') f
		INNER JOIN dbo.customer ci WITH (NOLOCK) ON f.val = ci.username
		INNER JOIN Dep_CustSuper s WITH(NOLOCK) ON ci.srecommend = s.custid
		LEFT JOIN Dep_CustVip cv WITH(NOLOCK) ON ci.custid = cv.custid
	WHERE ci.roleid = 1
										
	SELECT @ErrMsg = STUFF((SELECT ', '+ Username
							FROM @tmpCust t
								INNER JOIN bodb_Licensee.dbo.Licensees l WITH(NOLOCK) ON t.site = l.LicenseeName
							WHERE l.isAcknowledgement = 0
							FOR XML PATH('')),1,2,'')
	
	IF @ErrMsg <> ''
	BEGIN
		SELECT @ErrCode = 100,
				@ErrMsg = 'Not acknowledged licensee''s members cannot be reduced bet limit: ' +@ErrMsg
		RETURN;		
	END
	
	SELECT @ErrMsg = STUFF((SELECT ', '+ Username
							FROM @tmpCust t								
							WHERE isVip = 1
							FOR XML PATH('')),1,2,'')
	
	IF @ErrMsg <> ''
	BEGIN
		SELECT @ErrCode = 101,
				@ErrMsg = 'VIP members cannot be reduced bet limit: ' +@ErrMsg
		RETURN;		
	END
	
	--get old bet limit	
	UPDATE t 
	SET t.MaxBet = pa.MaxBet,
		t.MaxPerEvent = pa.MaxPerEvent
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId
	
	--update new bet limit
	UPDATE pa 
	SET pa.MaxBet = @MaxBet,
		pa.MaxPerEvent = @MaxPerMatch
	FROM dbo.ProblemAccount pa WITH (ROWLOCK)
		INNER JOIN @tmpCust t ON t.CustId = pa.CustId	
	
	-- Write log
	DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)
			
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
			AND custid IS NOT NULL
	
		IF @@ROWCOUNT = 0 BREAK	

		IF @Old_MaxBet IS NOT NULL
		BEGIN
			SELECT  @LogDataOld = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' MaxPerMatch="' + dbo.f_FomatNumber (CAST (@Old_MaxPerEvent AS VARCHAR(50))) + '"'
							+ ' MaxBet="' + dbo.f_FomatNumber (CAST (@Old_MaxBet AS VARCHAR(50))) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'
		END

		SELECT  @LogDataNew = '<R'
							+ ' Username="' + @UserName + '"'
							+ ' MaxPerMatch="' + dbo.f_FomatNumber (CAST (@MaxPerMatch AS VARCHAR(50))) + '"'
							+ ' MaxBet="' + dbo.f_FomatNumber (CAST (@MaxBet AS VARCHAR(50))) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'
							
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= 31629,
			@TrackingValue		= @LogDataNew,
			@TrackingValue2		= @LogDataOld,
			@Duration			= @Duration
	END	
END
GO
