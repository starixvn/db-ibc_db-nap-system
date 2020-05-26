/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_TypeInsert] 
	@BetLimitType VARCHAR(100) = '',
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
	Task : Bet Limit Control - Insert new Type 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:
	- @LiveIndicator : 0 : NonLive , 1: Live , 2 : Both, 3 : All
	- @ErrorCode: 
		1: The bet limit type exist already.

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(100) = '' 
	EXEC NAP_BLControl_TypeInsert 
		@BetLimitType = 'TypeD',
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
	IF EXISTS( SELECT TOP 1 1 FROM BetLimitControlType t WITH(NOLOCK) WHERE t.BetLimitType = @BetLimitType )
	BEGIN
		SELECT @ErrorCode = 1 ,
			@ErrorMsg = 'The bet limit type exist already.'

		RETURN
	END
END
GO


