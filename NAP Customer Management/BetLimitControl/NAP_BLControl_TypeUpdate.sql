/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_TypeUpdate] 
	@BetLimitTypeID INT,
	@ProductList VARCHAR(200) = '',
	@SporttypeList VARCHAR(MAX) = '',
	@BettypeList VARCHAR(MAX) =  '',
	@LiveIndicator	TINYINT = NULL,
	@LeagueGroupList VARCHAR(MAX) = '',
	@LeagueList VARCHAR(MAX) =  '',
	@BeginTime TIME = NULL,
	@EndTime TIME = NULL,
	@RestrictVIP BIT = NULL,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(100) = '' OUTPUT 
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - Update Type 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:
	- @LiveIndicator : 0 : NonLive , 1: Live , 2 : Both, 3 : All
	- @ErrorCode: 
		1: The bet limit type is no longer exists.

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(100) = '' 
	EXEC NAP_BLControl_TypeUpdate 
		@BetLimitTypeID = 1,
		@ProductList = '0',
		@SporttypeList = '0',
		@BettypeList = '0',
		@LiveIndicator = 3,
		@LeagueGroupList = '',
		@LeagueList =  '',
		@BeginTime = NULL,
		@EndTime = NULL,
		@RestrictVIP = NULL,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	IF NOT EXISTS( SELECT TOP 1 1 FROM BetLimitControlType t WITH(NOLOCK) WHERE t.BetLimitTypeID = @BetLimitTypeID )
	BEGIN
		SELECT @ErrorCode = 1 ,
			@ErrorMsg = 'The bet limit type is no longer exists.'

		RETURN
	END
END
GO


