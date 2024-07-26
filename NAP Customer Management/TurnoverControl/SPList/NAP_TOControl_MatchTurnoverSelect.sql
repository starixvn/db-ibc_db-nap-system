/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/ 
ALTER PROCEDURE [dbo].[NAP_TOControl_MatchTurnoverSelect]
(
	@UserName				NVARCHAR(50) = NULL,
	@UsedPercent			INT = 40, --% used should be > 0
	@MatchInfoJson		    VARCHAR(MAX) = NULL
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
		- 20230419@July: Turnover monitor showing live and non-live not correctly - [Redmine: #187148]
		- 20240726@July: Enhance performance of the function TO Monitor - [Redmine: 206673]
	
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
	
	DECLARE @SportType INT = 1
	       ,@Decompress_MatchInfoJson NVARCHAR(MAX) = NULL
	
	SET @Decompress_MatchInfoJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @MatchInfoJson, 1)) AS NVARCHAR(MAX))

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

	INSERT INTO #MatchList(matchid, homeid, awayid, eventdate, eventstatus, leagueid, IsNeutral, sporttype)
	SELECT matchid, homeid, awayid, eventdate, eventstatus, leagueid, IsNeutral, sporttype
	FROM OPENJSON(@Decompress_MatchInfoJson) 
			WITH(  matchid INT
				 , homeid INT
				 , awayid INT
				 , eventdate DATETIME
				 , eventstatus NVARCHAR(50)
				 , leagueid INT
				 , IsNeutral BIT
				 , sporttype SMALLINT
				)

	SET @SportType = (SELECT TOP 1 SportType FROM #MatchList)

	DECLARE @PercentLevel TINYINT = 0
	SELECT @PercentLevel = ISNULL((SELECT MAX(PercentLevel) FROM dbo.TOControl_LevelSetting WITH (NOLOCK) WHERE PercentValue <= @UsedPercent),0)

	CREATE TABLE #CTE_SettingList (
		  CustID INT
		, MatchId INT  
		, IsGroupHeadLine BIT 
		, ProfileID SMALLINT
		, IsEventLockTOLimit BIT
		, IsGlobalLockTOLimit BIT
		, PercentageUsed MONEY
		, PercentLevel TINYINT
		, MaxTurnover MONEY
		, TotalTurnover MONEY
		, HouseTurnover MONEY
	)
	CREATE TABLE #CTE_Filter_Sum (
		  CustID INT
		, MatchId INT 
		, IsGroupHeadLine BIT
		, ProfileID SMALLINT
		, GroupName NVARCHAR(50)
		, SumHouseTurnover MONEY
		, SumTotalTurnOver MONEY
	)

	INSERT INTO #CTE_SettingList (CustID, MatchId, IsGroupHeadLine, ProfileID, PercentageUsed, IsEventLockTOLimit, IsGlobalLockTOLimit, PercentLevel, MaxTurnover, HouseTurnover, TotalTurnover)
	SELECT t.CustID, t.MatchId, t.IsGroupHeadLine, t.ProfileID
		, CASE WHEN t.MaxTurnover = 0 THEN 100 ELSE ABS(t.HouseTurnover)*100/t.MaxTurnover END AS PercentageUsed
		, t.IsEventLockTOLimit, t.IsGlobalLockTOLimit, t.PercentLevel
		, MaxTurnover, ABS(t.HouseTurnover) AS HouseTurnover, TotalTurnover
	FROM #MatchList m 
		INNER JOIN dbo.TOControl_Setting t WITH(NOLOCK) ON m.matchid = t.matchid
		INNER JOIN dbo.custInfo c WITH (NOLOCK) ON t.custID = c.custid
	WHERE t.PercentLevel >= @PercentLevel 
		AND (ISNULL(@UserName,'') ='' OR c.username LIKE '%' + @UserName + '%') 
		AND t.ProfileID IS NOT NULL
			
	INSERT INTO #CTE_Filter_Sum (CustID, MatchId, IsGroupHeadLine, ProfileID, GroupName)
	SELECT DISTINCT CustID, MatchId, IsGroupHeadLine, p.ProfileID, p.GroupName
	FROM #CTE_SettingList 
		CROSS APPLY (
				SELECT ProfileID, GroupName
				FROM dbo.TOControl_Profile WITH (NOLOCK)
				WHERE Sporttype = CASE WHEN @SportType = 1 THEN 1
									   WHEN @Sporttype > 1 AND @SportType <= 99 THEN 99 
									   END
				)p
	WHERE PercentageUsed >= @UsedPercent 

	UPDATE cte
	SET cte.SumHouseTurnover = b.SumHouseTurnover
	  , cte.SumTotalTurnOver = b.SumTotalTurnOver
	FROM #CTE_Filter_Sum cte
		  CROSS APPLY(
			   SELECT SUM(ABS(t.HouseTurnover)) AS SumHouseTurnover, SUM(t.TotalTurnOver) AS  SumTotalTurnOver
			   FROM #CTE_SettingList t WITH (NOLOCK)
			   WHERE cte.MatchId = t.MatchId 
					AND cte.CustID = t.CustID 
					AND cte.IsGroupHeadLine = t.IsGroupHeadLine
		   )b

	SELECT m.sporttype
		  ,ct.CustID
		  ,c.username
		  , CASE WHEN ct.IsGroupHeadLine = 1 THEN 'RM' ELSE e.currency END AS currency
		  , CASE WHEN ct.IsGroupHeadLine = 1 THEN 'Headline'
		  		ELSE CASE c.RoleID WHEN 4 THEN 'Super'WHEN 3 THEN 'Master' WHEN 2 THEN 'Agent' END 
		  	END AS Level
		  , m.leagueid
		  , ct.MatchId
		  , m.IsNeutral
		  , m.homeid
		  , m.awayid
		  , m.eventdate
		  , m.eventstatus
		  , ct.ProfileID
		  , ct.GroupName
		  , ts.MaxTurnOver
		  , ts.TotalTurnOver
		  , ts.HouseTurnover
		  , ts.PercentageUsed
		  , ct.SumHouseTurnover AS TotalHouseTurnover
		  , ct.SumTotalTurnOver AS TotalMemberTurnover
		  , ISNULL(ts.IsEventLockTOLimit,0) AS IsEventLockTOLimit
		  , ISNULL(ts.IsGlobalLockTOLimit,0) AS IsGlobalLockTOLimit
	FROM  #CTE_Filter_Sum ct
			INNER JOIN #MatchList m WITH (NOLOCK) ON m.matchID = ct.matchid
			INNER JOIN dbo.custInfo c WITH (NOLOCK) ON ct.custID = c.custid
			INNER JOIN dbo.exchange e WITH (NOLOCK) ON c.currency = e.exchangeid
			LEFT JOIN  #CTE_SettingList ts		
						ON ct.MatchId = ts.MatchId
							AND ct.CustID = ts.CustID
							AND ct.IsGroupHeadLine = ts.IsGroupHeadLine
							AND ct.ProfileID = ts.profileID
	ORDER BY m.leagueid DESC
			, ct.MatchId ASC
			, c.username ASC
			, ct.ProfileID

	DROP TABLE #MatchList
	DROP TABLE #CTE_Filter_Sum
	DROP TABLE #CTE_SettingList

END
GO