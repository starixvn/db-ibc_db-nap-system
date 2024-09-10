/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_CustInsert] 
	@Usernames VARCHAR(MAX) = NULL,
	@BetLimitTypeID INT = NULL,
	@MaxBet MONEY = NULL,
	@MaxPerMatch MONEY = NULL,
	--@ErrorCode INT = 0 OUTPUT,
	--@ErrorMsg VARCHAR(200) = '' OUTPUT,
	@UserId INT = 0 ,
	@IP	VARCHAR(15) = '',
	@Mode TINYINT = 1  
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - Insert new CustSetting 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]
	- 20200922@Eden: BetLimitControl - Add multiple customers [RedmineID: #141767]
	- 20210513@Eden: BLC by pecentage of Match Max Bet [RedmineID: #154984]
	- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
	- 20240830@Johnson: Apply Inhouse for BLC [redmine:#209892]
	Parameter explanation:
	- @ErrorCode: 
		1: The bet limit type exist already.

	-@Mode:
		 1: Fixed Value
		 2: X times of Odds' Max Bet

	Example: 
	EXEC NAP_BLControl_CustInsert 
		@Usernames = 'member01,agent01,member0x',
		@BetLimitTypeID  = 1,
		@MaxBet  = 100,
		@MaxPerMatch  = 1000,
		@UserId = 8

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31753
	DECLARE @site  NVARCHAR(50), @BetLimitType VARCHAR(50)
	DECLARE @Username VARCHAR(30)
	DECLARE @ErrorCode INT = 0 , @ErrorMsg VARCHAR(200) = ''

	DECLARE @ErrorTbl TABLE (Username VARCHAR(30),ErrorCode INT , ErrorMsg VARCHAR(200))

	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey='CustomerManagement',
		@FunctionKey='BetLimitControl',
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
	BEGIN
		INSERT INTO @ErrorTbl(Username, ErrorCode, ErrorMsg)
		SELECT '', @ErrorCode, @ErrorMsg

		GOTO EndStep;
	END

	DECLARE @CustTbl TABLE ( UserName VARCHAR(30), Currency INT, IsFinished BIT DEFAULT 0)

	INSERT INTO @CustTBL(UserName)
	SELECT DISTINCT p.value
	FROM STRING_SPLIT(@Usernames,',') p
	WHERE value <> ''

	UPDATE t
	SET t.Currency = c.currency
	FROM @CustTbl t
		INNER JOIN custInfo c WITH(NOLOCK)
			ON t.UserName = c.username
	
	IF (SELECT COUNT(DISTINCT currency) FROM @CustTbl ) > 1
	BEGIN
		INSERT INTO @ErrorTbl(Username, ErrorCode, ErrorMsg)
		SELECT '', 4, 'All input accounts must belong to one currency only.'

		GOTO EndStep;
	END

	SELECT @BetLimitType = BetLimitType FROM BetLimitControlType WITH(NOLOCK) WHERE BetLimitTypeID = @BetLimitTypeID

	DECLARE @CustID INT

	WHILE 1 = 1
	BEGIN
		SELECT @ErrorCode = 0, 
			@ErrorMsg = '', 
			@CustID = NULL, 
			@Username = NULL , 
			@Site =  NULL

		UPDATE TOP(1) t
		SET t.IsFinished = 1,
			@Username = t.UserName
		FROM @CustTbl t
		WHERE IsFinished = 0

		IF @@ROWCOUNT = 0
			BREAK;

		EXEC NAP_BLControl_CustCheck 
			@Username = @Username,
			@userid = @userid,
			@BetLimitTypeID = @BetLimitTypeID,
			@ErrorCode = @ErrorCode OUTPUT,
			@ErrorMsg = @ErrorMsg OUTPUT,
			@CustID = @CustID OUTPUT,
			@Site = @site OUTPUT

		INSERT INTO @ErrorTbl(Username, ErrorCode, ErrorMsg)
		SELECT @Username, @ErrorCode, @ErrorMsg

		IF @ErrorCode =  0
		BEGIN
			SET @StartRun = GETDATE()

			INSERT INTO BetLimitControlCustSetting (CustID,BetLimitTypeID,MaxBet,MaxPerMatch,Mode,RepUpdateTime)
			SELECT @CustID,@BetLimitTypeID,@MaxBet,@MaxPerMatch,@Mode,SYSDATETIME()

			SET @EndRun = GETDATE()
			SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

			DECLARE @LogData VARCHAR(500)
			SELECT  @LogData = '<R '
								+ 'Type="'+ coalesce(cast(@BetLimitType as varchar(50)),space(1)) + '" ' 
								+ 'Mode="'+ coalesce(CASE WHEN @mode = 1 THEN 'Fixed Value' ELSE 'X times of Odds'' Max Bet' END ,space(1)) + '" ' 
								+ 'mpm="'+ coalesce(cast(@MaxPerMatch as varchar(50)),space(1)) + '" '
								+ 'maxb="'+ coalesce(cast(@MaxBet as varchar(50)),space(1)) + '" ' 
								+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
								+ ' />'

			IF @site = 'CN88'
			BEGIN
				EXEC dbo.CS_WriteLog_UserLog_RunSP_Wrapper
					@UserId				= @UserId,
					@CustId				= @CustId,
					@ActionId			= @ActionID,
					@TrackingValue		= @LogData,
					@Duration			= @Duration
			END
			ELSE -- MBC
			BEGIN
				EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
					@UserId				= @UserId,
					@CustId				= @CustId,
					@ActionId			= @ActionID,
					@TrackingValue		= @LogData,
					@Duration			= @Duration
			END
		END
	END

	EndStep:
	SELECT * FROM @ErrorTbl
END
GO


