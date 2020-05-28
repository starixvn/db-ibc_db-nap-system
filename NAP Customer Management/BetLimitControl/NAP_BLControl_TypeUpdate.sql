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
	@ErrorMsg VARCHAR(100) = '' OUTPUT,
	@UserId INT = 0 ,
	@IP	VARCHAR(15) = ''
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
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey='CustomerManagement',
		@FunctionKey='BetLimitTypeControl',
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		RETURN

	IF NOT EXISTS( SELECT TOP 1 1 FROM BetLimitControlType t WITH(NOLOCK) WHERE t.BetLimitTypeID = @BetLimitTypeID )
	BEGIN
		SELECT @ErrorCode = 1 ,
			@ErrorMsg = 'The bet limit type does not exist.'

		RETURN
	END

	CREATE TABLE #ValidData (
		ProductID TINYINT,
		Sporttype SMALLINT,
		Bettype SMALLINT,
		LeagueGroupID INT,
		LeagueID INT
	)

	EXEC NAP_BLControl_SportBettypeCheck 
		@ProductList = @ProductList,
		@SporttypeList = @SporttypeList,
		@BettypeList = @BettypeList,
		@LeagueGroupList = @LeagueGroupList,
		@LeagueList = @LeagueList,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT

	IF @ErrorCode <> 0 
	BEGIN
		RETURN
	END 

	SELECT @EndTime = DATEADD(ms,59999,@EndTime)

	--> Update BetLimitControlType
	UPDATE bc
	SET BeginTime = @BeginTime,
		EndTime = @EndTime,
		LiveIndicator = @LiveIndicator,
		RestrictVIP = @RestrictVIP
	FROM BetLimitControlType bc WITH(ROWLOCK,UPDLOCK)

	--> Reresh BetLimitControlTypeDetail
	MERGE BetLimitControlTypeDetail bc
	USING #ValidData t
		ON bc.ProductID = t.ProductID 
		AND bc.Sporttype = t.Sporttype
		AND bc.Bettype = t.Bettype 
		AND bc.LeagueGroupID = t.LeagueGroupID
		AND bc.LeagueID = t.LeagueID
	WHEN NOT MATCHED THEN INSERT (BetLimitTypeID,ProductID,Sporttype,Bettype,LeagueGroupID,LeagueID)
						VALUES( @BetLimitTypeID,t.ProductID,t.Sporttype,t.Bettype,t.LeagueGroupID,t.LeagueID)

	WHEN NOT MATCHED BY SOURCE AND bc.BetLimitTypeID = @BetLimitTypeID
		THEN DELETE; 
END
GO


