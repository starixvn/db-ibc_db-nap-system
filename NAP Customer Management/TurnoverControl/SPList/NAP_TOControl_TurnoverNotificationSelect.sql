/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_TurnoverNotificationSelect]
AS
/*
	Created: Don
	Date: 2017-03-23
	Task: Get Super/Master/Agent that reached notification thresholds
	DB: DBCUST.CustDB

	Revisions:
		- 20170920@Helen: TO Control Phase 3 - [Redmine: 75557]
		- 20190927@Helen: Differentiate alert thresholds between MBC and CN88 [Redmine: #119561]
		- 20191112@Helen: Ignore closed matches notification & SP Enhancement [Redmine: #122236]
		- 20200114@Malcolm: Separate setting and notification into Live/Non-Live and bettypes [Redmine : #126348]
		
	Parameter's explaination: 
	Hardcode:
			CROSS APPLY (SELECT CASE 
								WHEN PercentageUsed >= 100 THEN 100
								WHEN PercentageUsed >= 80 THEN 80
								WHEN PercentageUsed >= 60 THEN 60
								WHEN PercentageUsed >= 40 THEN 40
								ELSE 0
							END) _(nlevel)
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MatchList TABLE (matchid INT, homeid INT, awayid INT, eventdate DATETIME, sporttype INT, leagueid INT)

	DECLARE @temp_ TABLE (custid INT, matchid INT, totalturnover MONEY, MaxTurnover MONEY, houseturnover MONEY, nlevel TINYINT, IsGroupHeadline BIT, TotalMemberTurnover  MONEY, TotalHouseTurnover MONEY, ProfileID SMALLINT)

	DECLARE @NotifiedLevel INT
	
	SET @NotifiedLevel = (SELECT MIN(PercentLevel) FROM dbo.TOControl_LevelSetting WITH (NOLOCK) WHERE IsNotified = 1)
	
	;WITH cte_ AS (
		SELECT t.custid, t.matchid, t.totalturnover, t.MaxTurnover, t.houseturnover, t.IsNotified
				, CASE WHEN t.MaxTurnover = 0 THEN 100 ELSE t.houseturnover*100/t.MaxTurnover END AS PercentageUsed
				, t.IsGroupHeadline
				, t.ProfileID
				, st.siteid
		FROM dbo.TOControl_Setting t WITH(NOLOCK, INDEX = IX_PercentLevel)
			CROSS APPLY (SELECT TOP 1 ISNULL(ls.SiteID,0) AS SiteID
						FROM dbo.Customer c WITH (NOLOCK) 
							INNER JOIN dbo.Site s WITH (NOLOCK) ON c.site = s.site
							LEFT JOIN dbo.TOControl_LevelSetting ls WITH (NOLOCK) ON ls.SiteID =  s.siteid
						WHERE custid = t.CustID 
						) AS st
		WHERE t.PercentLevel >= @NotifiedLevel AND t.ProfileID IS NOT NULL
	), cte_sum AS (
	    SELECT t.CustID, t.matchid, t.IsGroupHeadLine, SUM(t.MaxTurnOver) AS TotalMemberTurnover, SUM(t.HouseTurnover) AS TotalHouseTurnover
		FROM TOControl_Setting t WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM cte_ cte WITH(NOLOCK) WHERE cte.CustID = t.CustID AND cte.matchid = t.matchid AND cte.IsGroupHeadLine = t.IsGroupHeadLine) 
			AND t.ProfileID IS NOT NULL
		GROUP BY t.CustID, t.matchid, t.IsGroupHeadLine
	)
	
	INSERT INTO @temp_(custid, matchid, totalturnover,ProfileID, MaxTurnover, houseturnover, nlevel,IsGroupHeadline, TotalMemberTurnover, TotalHouseTurnover)
	SELECT t.custid, t.matchid, t.totalturnover,t.ProfileID, t.MaxTurnover, t.houseturnover, nlevel,t.IsGroupHeadline, cs.TotalMemberTurnover, cs.TotalHouseTurnover
	FROM cte_ t WITH(NOLOCK)
	    INNER JOIN cte_sum cs WITH(NOLOCK) ON t.CustID = cs.CustID AND t.matchid = cs.matchid AND t.IsGroupHeadLine = cs.IsGroupHeadLine
		CROSS APPLY (SELECT MAX(PercentValue) 
					FROM dbo.TOControl_LevelSetting lst WITH (NOLOCK) 
					WHERE t.PercentageUsed >= lst.PercentValue AND lst.IsNotified = 1
							AND lst.SiteID = t.SiteID) _(nlevel)
		
	WHERE nlevel > t.IsNotified

	-- get match info
	INSERT INTO @MatchList(matchid, homeid, awayid, eventdate, sporttype, leagueid)
	SELECT m.matchid, m.homeid, m.awayid, m.eventdate, m.sporttype, m.leagueid
	FROM DBAGE.bodb02.dbo.match m WITH(NOLOCK)
	WHERE m.eventstatus = 'running' AND EXISTS(SELECT tmp.matchid FROM @temp_ tmp WHERE m.matchid = tmp.matchid)

	-- return result
	;WITH CTE_Result AS(
		SELECT 
		m.sporttype, m.leagueid, m.matchid, m.homeid, m.awayid, m.eventdate,
		c.custid, c.username
		, CASE WHEN t.IsGroupHeadline = 1 THEN 'RM' ELSE e.currency END AS currency
		, CASE WHEN t.IsGroupHeadline = 1 THEN 'Headline' 
											  ELSE CASE WHEN c.roleid = 4 THEN 'Super'
														WHEN c.roleid = 3 THEN 'Master'	
														WHEN c.roleid = 2 THEN 'Agent'	
														ELSE ''
													END	
										 END AS [Level]				
		, c.roleid
		, t.totalturnover, t.ProfileID,pf.ProfileName,t.maxturnover, t.houseturnover, t.nlevel , t.TotalMemberTurnover, t.TotalHouseTurnover
		, t.IsGroupHeadline
		, c.site AS SiteName 
		, CASE WHEN t.MaxTurnover = 0 THEN 100 ELSE t.houseturnover*100/t.MaxTurnover END AS PercentageUsed
		FROM @temp_ t
			INNER JOIN @MatchList m ON t.matchid = m.matchid
			INNER JOIN dbo.Customer c WITH(NOLOCK) ON t.custID = c.custid
			INNER JOIN dbo.exchange e WITH(NOLOCK) ON c.currency = e.exchangeid
			INNER JOIN TOControl_Profile pf WITH(NOLOCK) ON pf.ProfileID = t.ProfileID
	)
	SELECT ct.sporttype, ct.leagueid,ct.matchid,ct.homeid,ct.awayid,ct.eventdate,ct.custid,ct.username,ct.currency,ct.Level,
	       ct.roleid,ct.totalturnover,ct.ProfileID,ct.ProfileName,ct.MaxTurnover,ct.houseturnover,ct.nlevel,ct.TotalMemberTurnover,
	       ct.TotalHouseTurnover,ct.IsGroupHeadline,ct.SiteName,ct.PercentageUsed
	FROM CTE_Result ct WITH(NOLOCK)
    UNION ALL
	SELECT 
		m.sporttype, m.leagueid, m.matchid, m.homeid, m.awayid, m.eventdate,
		c.custid, c.username
		, CASE WHEN t.IsGroupHeadline = 1 THEN 'RM' ELSE e.currency END AS currency
		, CASE WHEN t.IsGroupHeadline = 1 THEN 'Headline' 
											  ELSE CASE WHEN c.roleid = 4 THEN 'Super'
														WHEN c.roleid = 3 THEN 'Master'	
														WHEN c.roleid = 2 THEN 'Agent'	
														ELSE ''
													END	
										 END AS [Level]				
		, c.roleid
		, t.totalturnover, t.ProfileID,pf.ProfileName,t.maxturnover, t.houseturnover, NULL AS nlevel , tmp.TotalMemberTurnover, tmp.TotalHouseTurnover
		, t.IsGroupHeadline
		, c.site AS SiteName 
		, CASE WHEN t.MaxTurnover = 0 THEN 100 ELSE t.houseturnover*100/t.MaxTurnover END AS PercentageUsed
	FROM dbo.TOControl_Setting t
		INNER JOIN @MatchList m ON t.matchid = m.matchid
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON t.custID = c.custid
		INNER JOIN dbo.exchange e WITH(NOLOCK) ON c.currency = e.exchangeid
		INNER JOIN TOControl_Profile pf WITH(NOLOCK) ON pf.ProfileID = t.ProfileID
	    INNER JOIN CTE_Result tmp ON tmp.custid = t.CustID AND tmp.matchid = t.matchid AND tmp.IsGroupHeadline = t.IsGroupHeadLine 
		                         AND NOT EXISTS(SELECT 1 FROM CTE_Result tm WHERE tm.custid = t.CustID AND tm.matchid = t.matchid AND tm.IsGroupHeadline = t.IsGroupHeadLine AND tm.ProfileID = t.ProfileID)

END
GO

