/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_PerformanceChecking_ReduceBetLimit] 
	@CustIDList VARCHAR(max)
AS
/*
	Created: 20200818@Eden
	Task : reduce BetLimit after Check Performance
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200818@Eden: Create New SP  [RedmineID: #139701]
	- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 

	Parameter explanation:
	EXEC NAP_BLControl_PerformanceChecking_ReduceBetLimit '1676188,1176092,28201722'

	*/
BEGIN
	SET NOCOUNT ON  
	DECLARE @startRun             DATETIME, 
			@endRun               DATETIME, 
			@duration             INT, 
			@CustID               INT, 
			@UserID               INT = 10278938, --starixIT 
			@BetLimitTypeID_Check INT = 25, --New Account Bet Limit by Performance
			@Update_CustIDList    VARCHAR(MAX) = '',		
			@Currency             INT, 
			@MaxPerMatch          MONEY, 
			@MaxBet               MONEY

	SET @startRun = getdate()

	DECLARE @Cust_Tbl TABLE ( CustID INT, Currency INT, IsFinished BIT DEFAULT 0)

	INSERT INTO @Cust_Tbl(CustID)
	SELECT p.value
	FROM STRING_SPLIT(@CustIDList,',') p
	WHERE value <> ''

	UPDATE t
	SET t.Currency = c.currency
	FROM custinfo c WITH(NOLOCK) 
		INNER JOIN @Cust_Tbl t ON c.custid = t.CustID

	DECLARE @actualRate_RMB float

	SELECT @actualRate_RMB = actualrate 
	FROM exchange WITH(NOLOCK)
	WHERE currency = 'RMB'

	WHILE 1 = 1
	BEGIN
		UPDATE TOP (1) @Cust_Tbl
		SET IsFinished = 1,
			@Currency = Currency,
			@CustID = CustID
		WHERE IsFinished = 0

		IF @@ROWCOUNT = 0
			BREAK;

		SELECT @MaxBet = CASE WHEN @Currency <> 20 THEN ROUND(50000.00 * @actualRate_RMB /actualrate, 0) ELSE 5000.00 END,
			@MaxPerMatch = CASE WHEN @Currency <> 20 THEN ROUND(50000.00 * @actualRate_RMB /actualrate, 0) ELSE 50000.00 END
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

				SELECT @Update_CustIDList = @Update_CustIDList + ',' + CONVERT(varchar,@CustID)
		END

	END

	SELECT @Update_CustIDList = STUFF(@Update_CustIDList,1,1,'')

	SET @endRun = getdate()  
	SET @duration  = datediff (millisecond,@startRun,@endRun) 
	DECLARE @NewLogData VARCHAR(MAX)
	SELECT @NewLogData = '<R '
						+ 'InputCustIDList="'+ coalesce(cast(@CustIDList as varchar(MAX)),space(1)) + '" '
						+ 'UpdatedCustIDList="'+ coalesce(cast(@Update_CustIDList as varchar(MAX)),space(1)) + '" '
						+ ' />'

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserId				= 0,
		@ActionId			= 31756,
		@TrackingValue		= @NewLogData,
		@Duration			= @Duration
END
GO


