/*<info serverAlias="DBCUST-CUSTDB" executers="Dot_Member,dot_intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Member_BetLimitControl_CustSettingSelect] 
	  @CustID		INT
	 ,@SportType    SMALLINT
	 ,@Bettype		SMALLINT
	 ,@LeagueID		INT
	 ,@LeagueGroupID INT = -1
	 ,@LiveIndicator BIT = NULL
	 ,@ProductID TINYINT = NULL
	 ,@OddsMaxBet MONEY = NULL
AS
/*

	Created: 20200602@Eden
	Task : get bet limit setting for member site
	DB: DBCUST-CUSTDB
	Original:

	Revisions:  
		- 20200602@Eden: Create New SP  [RedmineID: #132736]
		- 20210513@Eden: BLC by pecentage of Match Max Bet [RedmineID: #154984]
		- 20220304@Johnson: Add league group [RedmineID: #156808]
		- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
	Parameter explanation:

	Example: 
	EXEC Dot_Member_BetLimitControl_CustSettingSelect 
		@CustID = 1176092,@SportType = 1,
		@Bettype = 1,@LeagueID = 1,
		@LiveIndicator = 1,@ProductID = 1
	*/
BEGIN 
	DECLARE @bettime TIME = DATEADD(hh,12,GETDATE()) -- convert to GMT+8

	DECLARE @IsVIP BIT = 0

	IF NOT EXISTS ( SELECT TOP 1 1 FROM BetLimitControlProduct WITH(NOLOCK) WHERE ProductID = @ProductID)
	BEGIN
		SELECT CAST( NULL AS MONEY) AS MaxBet, CAST( NULL AS MONEY) AS MaxPerMatch
		RETURN
	END

	SELECT @IsVIP = 1 
	FROM Dep_CustVIP vip WITH(NOLOCK) 
	WHERE vip.CustID = @CustID

	SELECT MIN(CASE WHEN c.mode = 1 THEN c.MaxBet WHEN c.mode = 2 THEN @OddsMaxBet * c.MaxBet END ) AS MaxBet
		  ,MIN(CASE WHEN c.mode = 1 THEN c.MaxPerMatch WHEN c.mode = 2 THEN @OddsMaxBet * c.MaxPerMatch END ) AS MaxPerMatch
	FROM custinfo ci WITH(NOLOCK) 
		INNER JOIN BetLimitControlCustSetting c WITH(NOLOCK,FORCESEEK) ON c.CustID IN (ci.custid,ci.recommend,ci.mrecommend,ci.srecommend)
		INNER JOIN BetLimitControlType bt WITH(NOLOCK) ON c.BetLimitTypeID = bt.BetLimitTypeID
		INNER JOIN BetLimitControlTypeDetail btd WITH(NOLOCK) ON bt.BetLimitTypeID = btd.BetLimitTypeID
	WHERE ci.CustID = @CustID
			AND((	@bettime between bt.BeginTime AND bt.EndTime AND bt.BeginTime <= bt.EndTime) 
					OR ((@bettime >= bt.BeginTime OR @bettime <= bt.EndTime) AND bt.BeginTime > bt.EndTime)
					OR bt.BeginTime IS NULL
				)
			AND btd.Sporttype IN (@SportType,0)
			AND btd.Bettype IN (@Bettype,0)
			AND btd.LeagueID IN (ISNULL(@LeagueID,btd.LeagueID),0)
			AND btd.LeagueGroupID IN (@LeagueGroupID,-1)
			AND @LeagueGroupID NOT IN (SELECT value FROM STRING_SPLIT(ISNULL(bt.ExcludedLeagueGroupList,''),',') WHERE value <> '')
			AND bt.LiveIndicator IN(@LiveIndicator,2)
			AND (@IsVIP = 0 OR bt.RestrictVIP = 1)
			AND btd.ProductID IN (@ProductID,0)
	OPTION (FORCE ORDER)
END
GO