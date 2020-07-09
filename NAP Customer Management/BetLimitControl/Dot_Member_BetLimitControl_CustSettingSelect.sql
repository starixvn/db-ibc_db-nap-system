/*<info serverAlias="DBCUST-CUSTDB" executers="Dot_Member" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Member_BetLimitControl_CustSettingSelect] 
	  @CustID		INT
	 ,@SportType    SMALLINT
	 ,@Bettype		SMALLINT
	 ,@LeagueID		INT
	 ,@LeagueGroupID INT = 0
AS
/*
	Created: 20200602@Eden
	Task : get bet limit setting for member site
	DB: DBCUST-CUSTDB
	Original:

	Revisions:  
	- 20200602@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:

	Example: 
	EXEC Dot_Member_BetLimitControl_CustSettingSelect 
		@CustID = 1176092,
		@SportType = 1,
		@Bettype = 1,
		@LeagueID = 1
	*/
BEGIN 
	DECLARE @bettime TIME = GETDATE()

	DECLARE @IsVIP BIT = 0

	SELECT @IsVIP = 1 
	FROM Dep_CustVIP vip WITH(NOLOCK) 
	WHERE vip.CustID = @CustID

	--> option 2
	SELECT MIN(c.MaxBet) AS MaxBet,MIN(c.MaxPerMatch) AS MaxPerMatch
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
			AND btd.LeagueID IN (@LeagueID,0)
			AND btd.LeagueGroupID IN (@LeagueGroupID,0)
			AND (@IsVIP = 0 OR bt.RestrictVIP = 1)
	OPTION (FORCE ORDER)
END
GO