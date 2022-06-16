/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_EvidenceFlagged] 
	@CustIDList VARCHAR(max)
AS
/*
	Created: 20200818@Eden
	Task : CTS flag  evidence for customers
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200818@Eden: Create New SP  [RedmineID: #139701]
	- 20200922@Eden: BetLimitControl - Add multiple customers [RedmineID: #141767]
	- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 

	Parameter explanation:

	Examples:
		EXEC NAP_BLControl_Evidenceflagged @CustIDList = '1676188,1176092,28201722'

	*/
BEGIN
	SET NOCOUNT ON  
	DECLARE @startRun             DATETIME, 
			@endRun               DATETIME, 
			@duration             INT, 
			@CustID               INT, 
			@Username             VARCHAR(30), 
			@UserID               INT          = 10278938, --starixIT 
			@BetLimitTypeID_Check INT          = 24, --Bet Limit Control by Evidence
			@Currency             INT, 
			@MaxPerMatch          MONEY, 
			@MaxBet               MONEY, 
			@Update_CustIDList    VARCHAR(MAX) = ''

	SET @startRun = getdate()

	DECLARE @InputCust_Tbl TABLE ( RootCustID INT, CustID INT)
	DECLARE @Update_Cust_Tbl TABLE ( CustID INT PRIMARY KEY, Currency INT,Username VARCHAR(30), IsFinished BIT DEFAULT 0)
	
	INSERT INTO @InputCust_Tbl(CustID)
	SELECT p.value
	FROM STRING_SPLIT(@CustIDList,',') p
	WHERE value <> ''

	--> Process for all Customers belong to list of licensees
	INSERT INTO @Update_Cust_Tbl(CustID,Currency,Username)
	SELECT DISTINCT t.CustID,c.currency,c.username
	FROM @InputCust_Tbl t
		INNER JOIN custinfo c WITH(NOLOCK)
			ON c.custid = t.CustID AND c.roleid = 1
		INNER JOIN BetLimitControlDefaultSetting d WITH(NOLOCK)
			ON d.CustID IN ( c.srecommend,c.mrecommend,c.recommend)
	WHERE d.BetLimitTypeID = 25 --New Account Bet Limit by Performance

	IF NOT EXISTS( SELECT 1 FROM @Update_Cust_Tbl)
		RETURN

	DECLARE @actualRate_RMB float

	SELECT @actualRate_RMB = actualrate 
	FROM exchange WITH(NOLOCK)
	WHERE currency = 'RMB'

	WHILE 1 = 1
	BEGIN
		UPDATE TOP (1) @Update_Cust_Tbl
		SET IsFinished = 1,
			@Currency = Currency,
			@Username = Username,
			@CustID = CustID
		WHERE IsFinished = 0

		IF @@ROWCOUNT = 0
			BREAK;

		SELECT @MaxBet = CASE WHEN @Currency <> 20 THEN ROUND(3000.00 * @actualRate_RMB /actualrate, 0) ELSE 3000.00 END,
			@MaxPerMatch = CASE WHEN @Currency <> 20 THEN ROUND(3000.00 * @actualRate_RMB /actualrate, 0) ELSE 3000.00 END
		FROM exchange WITH(NOLOCK) 
		WHERE ExchangeId = @Currency

		IF EXISTS (	SELECT 1
					FROM BetLimitControlCustSetting c WITH(NOLOCK)
					WHERE c.BetLimitTypeID = @BetLimitTypeID_Check
						AND c.CustID = @CustID
					)
		BEGIN
			EXEC NAP_BLControl_CustUpdate 
				@CustID = @CustID,
				@BetLimitTypeID  = @BetLimitTypeID_Check,
				@NewBetLimitTypeID  = @BetLimitTypeID_Check,
				@MaxBet = @MaxBet,
				@MaxPerMatch = @MaxPerMatch,
				--@ErrorCode = @ErrorCode OUTPUT,
				--@ErrorMsg = @ErrorMsg OUTPUT,
				@UserId = @UserID
		END
		ELSE
		BEGIN
			EXEC NAP_BLControl_CustInsert 
				@Usernames = @Username,
				@BetLimitTypeID  = @BetLimitTypeID_Check,
				@MaxBet  = @MaxBet,
				@MaxPerMatch  = @MaxPerMatch,
				--@ErrorCode = @ErrorCode OUTPUT,
				--@ErrorMsg = @ErrorMsg OUTPUT,
				@UserId = @UserID
		END

		SELECT @Update_CustIDList = @Update_CustIDList + ',' + CONVERT(varchar,@CustID)
	END

	SELECT @Update_CustIDList = STUFF(@Update_CustIDList,1,1,'')

	SET @endRun = getdate()  
	SET @duration  = datediff (millisecond,@startRun,@endRun) 
	DECLARE @NewLogData VARCHAR(MAX)
	SELECT @NewLogData = '<R '
						+ 'CustIDList="'+ coalesce(cast(@CustIDList as varchar(MAX)),space(1)) + '" '
						+ 'UpdatedCustIDList="'+ coalesce(cast(@Update_CustIDList as varchar(MAX)),space(1)) + '" '
						+ ' />'

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserId				= 0,
		@ActionId			= 31758,
		@TrackingValue		= @NewLogData,
		@Duration			= @Duration
END
GO


