/*<info serverAlias="DBAGE-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_MatchSelect]
	@LeagueID				INT = 0,
	@FromDate				DATETIME = NULL,
	@ToDate					DATETIME = NULL,
	@SportType				INT = 1, 
	@MatchID				INT = 0,
	@IsExcludeCompletedEvent BIT = 0,
	@MoveBetsDay			DATETIME = NULL,
	@IsSubmit				BIT = 0
AS
/*
	Created: Don
	Date: 2017-03-27
	Task: Retrieve list of matches
	DB: DBAGE.bodb02

	Revisions:
		- 20170920@Helen: TO Control Phase 3 - [Redmine: 75557]
		- 20211117@July: In-house Replication - [Redmine: 164660]
		- 20240726@July: Enhance performance of the function TO Monitor - [Redmine: 206673]

	Parameter's explaination:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MatchInfoJson		VARBINARY(MAX) = NULL

	IF @IsSubmit = 0 --Get matches
	BEGIN
		--#1: When select League load matches infor
		SELECT m.matchid, m.eventdate, m.homeid, m.awayid, m.IsNeutral
		FROM dbo.match m WITH (NOLOCK)
		WHERE (@LeagueID = 0 OR m.leagueid = @LeagueID )
			AND m.eventdate BETWEEN @FromDate AND @ToDate 
			AND m.matchcode NOT LIKE '%hedge%'
			AND ISNULL(m.IsDeleted,0) = 0
		ORDER BY m.eventdate

		--#2: When Submit return matches infor (NO Data -> must return)
		SELECT @MatchInfoJson AS MatchInfoJson

		RETURN;
	END

	CREATE TABLE #MatchList(
		  matchid INT
		, homeid INT
		, awayid INT
		, eventdate DATETIME
		, eventstatus NVARCHAR(50)
		, leagueid INT
		, IsNeutral BIT
		, sporttype SMALLINT
	)

	IF @IsSubmit = 1 --Get search
	BEGIN
		--#1: When select League load matches infor (NO Data -> must return)
		SELECT matchid, eventdate, homeid, awayid, IsNeutral
		FROM #MatchList
		
		--#2: When Submit return matches infor
		IF @Todate <= @MoveBetsDay
		BEGIN
			INSERT INTO #MatchList(matchid, homeid, awayid, eventdate, eventstatus, leagueid, IsNeutral, sporttype)
			SELECT m.matchid, m.homeid, m.awayid, m.eventdate, m.eventstatus, m.leagueid, m.IsNeutral, m.sporttype
			FROM dbo.match14 m WITH(NOLOCK)
			WHERE 
				m.eventdate BETWEEN @FromDate AND @ToDate
				AND m.sporttype = @SportType
				AND m.leagueid = CASE WHEN @LeagueID = 0 THEN m.leagueid ELSE @LeagueID END
				AND m.matchid = CASE WHEN @MatchID = 0 THEN m.matchid ELSE @MatchID END
				AND (@IsExcludeCompletedEvent = 0 OR (@IsExcludeCompletedEvent = 1 AND m.eventstatus <> 'completed'))
				
		END
		ELSE IF @FromDate > @MoveBetsDay
		BEGIN
			INSERT INTO #MatchList(matchid, homeid, awayid, eventdate, eventstatus, leagueid, IsNeutral, sporttype)
			SELECT m.matchid, m.homeid, m.awayid, m.eventdate, m.eventstatus, m.leagueid, m.IsNeutral, m.sporttype
			FROM dbo.match m WITH(NOLOCK)
			WHERE 
				m.eventdate BETWEEN @FromDate AND @ToDate
				AND m.sporttype = @SportType
				AND m.leagueid = CASE WHEN @LeagueID = 0 THEN m.leagueid ELSE @LeagueID END
				AND m.matchid = CASE WHEN @MatchID = 0 THEN m.matchid ELSE @MatchID END
				AND (@IsExcludeCompletedEvent = 0 OR (@IsExcludeCompletedEvent = 1 AND m.eventstatus <> 'completed'))
				AND ISNULL(m.IsDeleted,0) = 0
		END
		ELSE
		BEGIN
			INSERT INTO #MatchList(matchid, homeid, awayid, eventdate, eventstatus, leagueid, IsNeutral, sporttype)
			SELECT m.matchid, m.homeid, m.awayid, m.eventdate, m.eventstatus, m.leagueid, m.IsNeutral, m.sporttype
			FROM dbo.match m WITH(NOLOCK)
			WHERE 
				m.eventdate BETWEEN @MoveBetsDay AND @ToDate
				AND m.sporttype = @SportType
				AND m.leagueid = CASE WHEN @LeagueID = 0 THEN m.leagueid ELSE @LeagueID END
				AND m.matchid = CASE WHEN @MatchID = 0 THEN m.matchid ELSE @MatchID END
				AND (@IsExcludeCompletedEvent = 0 OR (@IsExcludeCompletedEvent = 1 AND m.eventstatus <> 'completed'))
				AND ISNULL(m.IsDeleted,0) = 0
			
			UNION ALL

			SELECT m.matchid, m.homeid, m.awayid, m.eventdate, m.eventstatus, m.leagueid, m.IsNeutral, m.sporttype
			FROM dbo.match14 m WITH(NOLOCK)
			WHERE 
				m.eventdate BETWEEN @FromDate AND @MoveBetsDay
				AND m.sporttype = @SportType
				AND m.leagueid = CASE WHEN @LeagueID = 0 THEN m.leagueid ELSE @LeagueID END
				AND m.matchid = CASE WHEN @MatchID = 0 THEN m.matchid ELSE @MatchID END
				AND (@IsExcludeCompletedEvent = 0 OR (@IsExcludeCompletedEvent = 1 AND m.eventstatus <> 'completed'))
		END	

		SET @MatchInfoJson = COMPRESS((
			SELECT matchid AS 'matchid'
				  ,homeid AS 'homeid'
				  ,awayid AS 'awayid'
				  ,eventdate AS 'eventdate'
				  ,eventstatus AS 'eventstatus'
				  ,leagueid AS 'leagueid'
				  ,IsNeutral AS 'IsNeutral'
				  ,sporttype AS 'sporttype'
			FROM #MatchList
			WHERE @IsSubmit = 1 
		FOR JSON PATH))

		SELECT CONVERT(VARCHAR(MAX), @MatchInfoJson, 1) AS MatchInfoJson
		
		DROP TABLE #MatchList

		RETURN;
	END

END
GO
