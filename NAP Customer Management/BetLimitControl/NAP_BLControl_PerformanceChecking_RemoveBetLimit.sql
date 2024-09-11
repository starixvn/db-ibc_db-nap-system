/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_PerformanceChecking_RemoveBetLimit] 
	@CustIDList VARCHAR(max)
AS
/*
	Created: 20200818@Eden
	Task : Remove Bet Limit control after Check Performance
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200818@Eden: Create New SP  [RedmineID: #139701]
	- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 

	Parameter explanation:
	*/
BEGIN
	SET NOCOUNT ON  
	DECLARE @startRun             DATETIME, 
			@endRun               DATETIME, 
			@duration             INT, 
			@CustID               INT, 
			@UserID               INT = 10278938, --starixIT 
			@BetLimitTypeID_Check INT = 25, --New Account Bet Limit by Performance 
			@Remove_CustIDList    VARCHAR(MAX) = ''

	SET @startRun = getdate()

	DECLARE @Cust_Tbl TABLE ( CustID INT, IsFinished BIT DEFAULT 0)

	INSERT INTO @Cust_Tbl(CustID)
	SELECT p.value
	FROM STRING_SPLIT(@CustIDList,',') p
	WHERE value <> ''

	WHILE 1 = 1
	BEGIN
		UPDATE TOP (1) @Cust_Tbl
		SET IsFinished = 1,
			@CustID = CustID
		WHERE IsFinished = 0

		IF @@ROWCOUNT = 0
			BREAK;

		IF EXISTS (	SELECT 1
					FROM BetLimitControlCustSetting c WITH(NOLOCK)
					WHERE c.BetLimitTypeID = @BetLimitTypeID_Check
						AND c.CustID = @CustID
					)
		BEGIN
			EXEC NAP_BLControl_CustDelete 
				@CustID = @CustID,
				@BetLimitTypeID  = @BetLimitTypeID_Check,
				--@ErrorCode = @ErrorCode OUTPUT,
				--@ErrorMsg = @ErrorMsg OUTPUT,
				@UserId = @UserId

			SELECT @Remove_CustIDList = @Remove_CustIDList + ',' + CONVERT(varchar,@CustID)
		END

	END

	SELECT @Remove_CustIDList = STUFF(@Remove_CustIDList,1,1,'')

	SET @endRun = getdate()  
	SET @duration  = datediff (millisecond,@startRun,@endRun) 
	DECLARE @NewLogData VARCHAR(MAX)
	SELECT @NewLogData = '<R '
						+ 'InputCustIDList="'+ coalesce(cast(@CustIDList as varchar(MAX)),space(1)) + '" '
						+ 'RemoveCustIDList="'+ coalesce(cast(@Remove_CustIDList as varchar(MAX)),space(1)) + '" '
						+ ' />'

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserId				= 0,
		@ActionId			= 31757,
		@TrackingValue		= @NewLogData,
		@Duration			= @Duration
END
GO


