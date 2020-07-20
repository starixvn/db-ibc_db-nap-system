/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/ 
ALTER PROCEDURE [dbo].[NAP_TOControl_MatchTurnoverSelect]
(
	@SportType				INT = 1, 
	@LeagueID				INT = 0,
	@MatchID				INT = 0,
	@UserName				NVARCHAR(50),
	@IsExcludeCompletedEvent BIT = 0,
	@UsedPercent			INT = 40,
	@FromDate				DATETIME, 
	@ToDate					DATETIME,
	@MoveBetsDay			DATETIME
)	
AS
/*
	Created: Don
	Date: 2017-03-23
	Task: Retrieve Super/Master/Agent Turnover List
	DB: DBCUST.CustDB

	Revisions:
		- 20170920@Helen: TO Control Phase 3 - [Redmine: 75557]
		- 20171215@Helen: Implement some change request from OPS Team - [Redmine: 85638]
		- 20200115@Malcolm: Separate setting and notification into Live/Non-Live and bettypes [Redmine : #126348]
		- 20200120@Max: Support Separate setting and notification into Live/Non-Live major and minor bettypes [Redmine: #126841]
		- 20200714@Max: SMA TO Control - Add block increasing TO Limit feature to specific SMAs - [Redmine: #136254]
	
	Parameter's explaination: 
	HARDCODE for @PercentLevel
	CASE
			WHEN @UsedPercent >= 100 THEN 10
			WHEN @UsedPercent >= 80 THEN 8
			WHEN @UsedPercent >= 60 THEN 6
			WHEN @UsedPercent >= 40 THEN 4
			ELSE 0
	END
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MatchList(matchid INT, homeid INT, awayid INT, eventdate DATETIME, eventstatus NVARCHAR(50), leagueid INT, IsNeutral BIT)

	DECLARE @PercentLevel TINYINT = 0
	SELECT @PercentLevel = ISNULL((SELECT MAX(PercentLevel) FROM dbo.TOControl_LevelSetting WITH (NOLOCK) WHERE @UsedPercent  >=  PercentValue),0)
		
	/* Get information about needed events */
	IF @Todate <= @MoveBetsDay
	BEGIN
		INSERT INTO #MatchList(matchid, homeid, awayid, eventdate, eventstatus, leagueid,IsNeutral )
			SELECT m.matchid, m.homeid, m.awayid, m.eventdate, m.eventstatus, m.leagueid, m.IsNeutral
			FROM DBAGE.bodb02.dbo.match14 m WITH(NOLOCK)
			WHERE 
				m.eventdate BETWEEN @FromDate AND @ToDate
				AND m.sporttype = @SportType
				AND m.leagueid = CASE WHEN @LeagueID = 0 THEN m.leagueid ELSE @LeagueID END
				AND m.matchid = CASE WHEN @MatchID = 0 THEN m.matchid ELSE @MatchID END
				AND (@IsExcludeCompletedEvent = 0 OR (@IsExcludeCompletedEvent = 1 AND m.eventstatus <> 'completed'))
				
	END
	ELSE IF @FromDate > @MoveBetsDay
	BEGIN
		INSERT INTO #MatchList(matchid, homeid, awayid, eventdate, eventstatus, leagueid,IsNeutral)
			SELECT m.matchid, m.homeid, m.awayid, m.eventdate, m.eventstatus, m.leagueid, m.IsNeutral
			FROM DBAGE.bodb02.dbo.match m WITH(NOLOCK)
			WHERE 
				m.eventdate BETWEEN @FromDate AND @ToDate
				AND m.sporttype = @SportType
				AND m.leagueid = CASE WHEN @LeagueID = 0 THEN m.leagueid ELSE @LeagueID END
				AND m.matchid = CASE WHEN @MatchID = 0 THEN m.matchid ELSE @MatchID END
				AND (@IsExcludeCompletedEvent = 0 OR (@IsExcludeCompletedEvent = 1 AND m.eventstatus <> 'completed'))
	END
	ELSE
	BEGIN
		INSERT INTO #MatchList(matchid, homeid, awayid, eventdate, eventstatus, leagueid,IsNeutral)
			SELECT m.matchid, m.homeid, m.awayid, m.eventdate, m.eventstatus, m.leagueid,m.IsNeutral
			FROM DBAGE.bodb02.dbo.match m WITH(NOLOCK)
			WHERE 
				m.eventdate BETWEEN @MoveBetsDay AND @ToDate
				AND m.sporttype = @SportType
				AND m.leagueid = CASE WHEN @LeagueID = 0 THEN m.leagueid ELSE @LeagueID END
				AND m.matchid = CASE WHEN @MatchID = 0 THEN m.matchid ELSE @MatchID END
				AND (@IsExcludeCompletedEvent = 0 OR (@IsExcludeCompletedEvent = 1 AND m.eventstatus <> 'completed'))

			UNION ALL

			SELECT m.matchid, m.homeid, m.awayid, m.eventdate, m.eventstatus, m.leagueid,m.IsNeutral
			FROM DBAGE.bodb02.dbo.match14 m WITH(NOLOCK)
			WHERE 
				m.eventdate BETWEEN @FromDate AND @MoveBetsDay
				AND m.sporttype = @SportType
				AND m.leagueid = CASE WHEN @LeagueID = 0 THEN m.leagueid ELSE @LeagueID END
				AND m.matchid = CASE WHEN @MatchID = 0 THEN m.matchid ELSE @MatchID END
				AND (@IsExcludeCompletedEvent = 0 OR (@IsExcludeCompletedEvent = 1 AND m.eventstatus <> 'completed'))
	END	

	/* Get list of Super/Master/Agent turnover */
	;WITH CTE_Filter AS (
	   SELECT tb.CustID, tb.matchid, tb.IsGroupHeadLine, tb.IsEventLockTOLimit, tb.IsGlobalLockTOLimit
	   FROM (
			SELECT t.CustID, t.matchid,
				   CASE WHEN t.MaxTurnover = 0 THEN 100 ELSE ABS(t.HouseTurnover)*100/t.MaxTurnover END AS PercentageUsed,
				   t.IsGroupHeadLine, t.IsEventLockTOLimit, t.IsGlobalLockTOLimit
			FROM dbo.TOControl_Setting t WITH(NOLOCK) 
				INNER JOIN dbo.custInfo c WITH (NOLOCK) ON t.custID = c.custid
			WHERE t.PercentLevel >= @PercentLevel AND
				 (ISNULL(@UserName,'')='' OR c.username LIKE '%' + @UserName + '%') AND t.ProfileID IS NOT NULL
		   ) AS tb
	   WHERE @UsedPercent <= tb.PercentageUsed

	),CTE_SettingList AS (
		SELECT 
			t.CustID, t.matchid, t.MaxTurnover, t.TotalTurnover, t.HouseTurnover AS HouseTurnover
			, CASE WHEN t.MaxTurnover = 0 THEN 100 ELSE ABS(t.HouseTurnover)*100/t.MaxTurnover END AS PercentageUsed
			, t.IsGroupHeadLine
			, t.ProfileID 
			, t.PercentLevel
		FROM dbo.TOControl_Setting t WITH(NOLOCK) 
		WHERE EXISTS( SELECT 1 FROM CTE_Filter tf  WITH(NOLOCK) WHERE t.CustID = tf.CustID AND t.IsGroupHeadLine = tf.IsGroupHeadLine AND t.matchid = tf.matchid) AND t.ProfileID IS NOT NULL	
		
	), CTE_Sum AS(
	       SELECT t.CustID,t.matchid,t.IsGroupHeadLine,ABS(SUM(t.HouseTurnover)) AS SumHouseTurnover, SUM(t.TotalTurnOver) AS  SumTotalTurnOver
		   FROM CTE_SettingList t WITH (NOLOCK)
		   GROUP BY t.matchid, t.CustID, t.IsGroupHeadLine
	)
	SELECT CASE WHEN @SportType = 1 THEN 1 ELSE 99 END AS SportType
		, pf.CustID
		, c.username
		, CASE WHEN pf.IsGroupHeadLine = 1 THEN 'RM' ELSE e.currency END AS currency
		, CASE WHEN pf.IsGroupHeadLine = 1 THEN 'Headline'
				ELSE	CASE c.RoleID WHEN 4 THEN 'Super' WHEN 3 THEN 'Master' WHEN 2 THEN 'Agent' END 
			END AS Level
		, m.leagueid
		, pf.matchID
		, m.IsNeutral
		, m.homeid
		, m.awayid
		, m.eventdate
		, m.eventstatus
		, pf.ProfileID
		, pf.GroupName
		, ts.MaxTurnOver
		, ts.TotalTurnOver
		, ABS(ts.HouseTurnover) AS HouseTurnover
		, ts.PercentageUsed
		, s.SumHouseTurnover AS TotalHouseTurnover
		, s.SumTotalTurnOver AS TotalMemberTurnover
		, ISNULL(pf.IsEventLockTOLimit,0) AS IsEventLockTOLimit
		, ISNULL(pf.IsGlobalLockTOLimit,0) AS IsGlobalLockTOLimit
	FROM (
			SELECT ct.CustID, ct.matchid, ct.IsGroupHeadLine, p.ProfileID, p.GroupName, ct.IsEventLockTOLimit, ct.IsGlobalLockTOLimit
			FROM (
					SELECT DISTINCT t.CustID, t.IsGroupHeadLine, t.matchid, t.IsEventLockTOLimit, t.IsGlobalLockTOLimit
					FROM CTE_Filter t
				)ct
				CROSS APPLY (
							SELECT ProfileID, GroupName
							FROM TOControl_Profile WITH (NOLOCK)
							WHERE Sporttype = CASE WHEN @SportType = 1 THEN 1
												WHEN @Sporttype > 1 AND @SportType <= 99 THEN 99 
												END
							)p
		) pf
		OUTER APPLY (
					SELECT t.MaxTurnover
							, t.TotalTurnover
							, t.HouseTurnover
							, t.PercentageUsed
					FROM  CTE_SettingList t		
					WHERE pf.matchid = t.matchid
						AND pf.custid = t.CustID
						AND pf.isgroupHeadline = t.IsGroupHeadLine
						AND pf.ProfileID = t.profileID
			)ts
		LEFT JOIN CTE_Sum s WITH(NOLOCK) ON pf.CustID = s.CustID AND pf.matchid = s.matchid AND pf.IsGroupHeadLine = s.IsGroupHeadLine
		INNER JOIN #MatchList m WITH (NOLOCK) ON m.matchID = pf.matchid
		INNER JOIN dbo.custInfo c WITH (NOLOCK) ON pf.custID = c.custid
		INNER JOIN dbo.exchange e WITH (NOLOCK) on c.currency = e.exchangeid
		
	DROP TABLE #MatchList

END
GO