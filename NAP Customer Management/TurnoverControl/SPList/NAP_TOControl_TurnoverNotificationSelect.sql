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
		- 20200122@Max: Support Separate setting and notification into Live/Non-Live major and minor bettypes [Redmine: #126841] 
		- 20200720@Helen: SMA TO Control - change formula to use max Exposure when forecasting the risk - [Redmine: #136254]
		- 20200812@Helen: SMA TO Control - Performance Tuning - [Redmine: #139387]
		- 20201130@July: Support CRM - Automate adding feedback If SMA reach Company Turnover Control - [Redmine: #145274]
		- 20210318@Helen: SMA TO Control - Config to capture UUS Currency only on UAT to avoid SMA TO email duplication - [Redmine: #151926]
		- 20210414@Max: SMA TO Control - Performance Tuning - [Redmine: #153447]
		- 20210504@July: SMA TO Control - Change Global Setting for EC2021 - [Redmine: #130912]
		
		
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
	
	DECLARE @procName NVARCHAR(50), @IsTest BIT =  0, @currentDate DATETIME, @n INT= 2147483647
	SET @procName = OBJECT_NAME(@@procid)
	
	IF @procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_'
	BEGIN
		SET @IsTest = 1
	END
		
	DECLARE @MatchList TABLE (matchid INT, homeid INT, awayid INT, eventdate DATETIME, sporttype INT, leagueid INT)

	DECLARE @temp_ TABLE (
				rn INT, custid INT, matchid INT, totalturnover MONEY
				, MaxTurnover MONEY, houseturnover MONEY, nlevel TINYINT, IsGroupHeadline BIT
				, TotalMemberTurnover  MONEY, TotalHouseTurnover MONEY, ProfileID SMALLINT
				, PercentageUsed MONEY
				, username VARCHAR(30)
				, roleid TINYINT
				, currency INT
				, site VARCHAR(10)
		)

	DECLARE @NotifiedLevel_mbc INT --, @NotifiedLevel_cn88 INT
		
	SET @NotifiedLevel_mbc =  (SELECT MIN(PercentLevel) FROM dbo.TOControl_LevelSetting WITH (NOLOCK) WHERE IsNotified = 1 AND siteid = 0)
	--SET @NotifiedLevel_cn88 = (SELECT MIN(PercentLevel) FROM dbo.TOControl_LevelSetting WITH (NOLOCK) WHERE IsNotified = 1 AND siteid = 329)
	
	INSERT INTO @MatchList(matchid, homeid, awayid, eventdate, sporttype, leagueid)
	SELECT m.matchid, m.homeid, m.awayid, m.eventdate, m.sporttype, m.leagueid
	FROM DBAGE.bodb02.dbo.match m WITH(NOLOCK)
	WHERE m.eventstatus = 'running' AND m.sporttype < 99
	
	CREATE TABLE #Setting_tmp(custid INT
							, username VARCHAR(30)
							, roleid TINYINT
							, currency INT
							, matchid INT, TotalTurnOver MONEY, MaxTurnover MONEY
							,houseturnover MONEY, IsNotified BIT, PercentageUsed	MONEY, IsGroupHeadline BIT
							,ProfileID SMALLINT, site VARCHAR(10), nlevel TINYINT)
	
	INSERT INTO #Setting_tmp (custid,username, roleid,currency, matchid, TotalTurnOver, MaxTurnover,houseturnover, IsNotified, PercentageUsed	, IsGroupHeadline,ProfileID, site, nlevel)						
	SELECT t.custid, c.username, c.roleid, c.currency, t.matchid, t.totalturnover, t.MaxTurnover, ABS(t.houseturnover) AS houseturnover, t.IsNotified
			, tmp.PercentageUsed
			, t.IsGroupHeadline
			, t.ProfileID
			, c.site
			, nlevel
	FROM (SELECT TOP (@n) matchid, homeid, awayid, eventdate, sporttype, leagueid FROM @MatchList) m  
		INNER LOOP JOIN dbo.TOControl_Setting t WITH(NOLOCK, INDEX = ix_TOControl_Setting_matchid) ON m.matchid = t.matchid
		INNER JOIN dbo.Customer c WITH (NOLOCK) ON c.custid = t.CustID
		CROSS APPLY (SELECT CASE WHEN t.MaxTurnover = 0 THEN 100 ELSE ABS(t.houseturnover)*100/ABS(t.MaxTurnover) END AS PercentageUsed
					)  AS tmp
		CROSS APPLY (SELECT MAX(PercentValue) 
					FROM dbo.TOControl_LevelSetting lst WITH (NOLOCK) 
					WHERE tmp.PercentageUsed >= lst.PercentValue AND lst.IsNotified = 1
							AND lst.SiteID = 0 --(CASE WHEN c.Site = 'CN88' THEN 329 ELSE 0 END)
						) _(nlevel)
	
	WHERE /*1 = CASE WHEN t.PercentLevel >= @NotifiedLevel_cn88 AND c.Site = 'CN88' THEN 1
				  WHEN t.PercentLevel >= @NotifiedLevel_mbc AND ISNULL(c.Site,'') <> 'CN88' THEN 1
				  ELSE 0
			END	 */
			t.PercentLevel >= @NotifiedLevel_mbc AND ISNULL(c.Site,'') <> 'CN88'
		 AND nlevel > t.IsNotified
		 AND c.currency = CASE WHEN @IsTest = 1 THEN 20 ELSE c.currency END
		 
	OPTION (MAXDOP 1, OPTIMIZE FOR (@n = 1))
	
	;WITH cte_sum AS (
	    SELECT t.CustID, t.matchid, t.IsGroupHeadLine, Total.TotalMemberTurnover, Total.TotalHouseTurnover
		FROM  (SELECT DISTINCT CustID, matchid, IsGroupHeadLine FROM #Setting_tmp) AS t
			CROSS APPLY (SELECT SUM(t1.TotalTurnOver) AS TotalMemberTurnover, ABS(SUM(t1.HouseTurnover)) AS TotalHouseTurnover
						 FROM dbo.TOControl_Setting t1 WITH(NOLOCK)
						 WHERE t.CustID = t1.custid AND t.matchid = t1.matchid AND t.IsGroupHeadLine = t1.IsGroupHeadLine
						 ) AS Total
	)
	INSERT INTO @temp_(rn, custid, username, roleid, currency ,site, matchid, totalturnover,ProfileID, MaxTurnover, houseturnover, nlevel,IsGroupHeadline, TotalMemberTurnover, TotalHouseTurnover, PercentageUsed)
	SELECT ROW_NUMBER() OVER(ORDER BY t.CustId, t.MatchId) AS rn 
		, t.custid, t.username, t.roleid, t.currency, t.site
		, t.matchid, t.totalturnover,t.ProfileID, t.MaxTurnover, t.houseturnover, nlevel,t.IsGroupHeadline, cs.TotalMemberTurnover, cs.TotalHouseTurnover
		, PercentageUsed
	FROM #Setting_tmp t WITH(NOLOCK)
	    INNER JOIN cte_sum cs WITH(NOLOCK) ON t.CustID = cs.CustID AND t.matchid = cs.matchid AND t.IsGroupHeadLine = cs.IsGroupHeadLine
	
	-- return result
	SELECT 
		pf.sporttype 
		, m.leagueid
		, pf.matchid
		, m.homeid
		, m.awayid
		, m.eventdate
		, pf.custid
		, pf.username
		, CASE WHEN pf.IsGroupHeadline = 1 THEN 'RM' ELSE e.currency END AS currency
		, CASE WHEN pf.IsGroupHeadline = 1 THEN 'Headline' 
				ELSE CASE WHEN pf.roleid = 4 THEN 'Super'
						WHEN pf.roleid = 3 THEN 'Master'	
						WHEN pf.roleid = 2 THEN 'Agent'	
						ELSE ''
					END	
			END AS [Level]
		, pf.roleid
		, ISNULL(t.totalturnover, 0) AS totalturnover
		, pf.ProfileID
		, pf.ProfileName
		, ISNULL(t.maxturnover, 0) AS maxturnover
		, ABS(ISNULL(t.houseturnover, 0)) AS houseturnover
		, tmp.nlevel AS nlevel 
		, pf.TotalMemberTurnover
		, pf.TotalHouseTurnover
		, pf.IsGroupHeadline
		, pf.site AS SiteName 
		, CASE WHEN t.MaxTurnover = 0 THEN 100 ELSE ABS(t.houseturnover/t.MaxTurnover) END AS PercentageUsed
		, pf.rn AS DisplayGroup
	FROM 
		(
			SELECT ct.CustID,ct.currency,ct.username,ct.roleid,ct.Site, ct.matchid, ct.IsGroupHeadLine, p.ProfileID, p.GroupName, ct.sporttype, p.ProfileName, TotalHouseTurnover, TotalMemberTurnover, rn
			FROM (
					SELECT DISTINCT t.CustID,t.username,t.roleid, t.IsGroupHeadLine, t.matchid, TotalHouseTurnover, TotalMemberTurnover, MAX(rn) AS rn
						, CASE WHEN t.ProfileID <= 10 THEN 1 ELSE 99 END AS sporttype
						, currency
						, t.site
					FROM @temp_ t
					GROUP BY t.CustID, t.currency,t.username,t.roleid, t.site, t.IsGroupHeadLine, t.matchid, TotalHouseTurnover, TotalMemberTurnover, CASE WHEN t.ProfileID <= 10 THEN 1 ELSE 99 END
				)ct
				CROSS APPLY (
							SELECT ProfileID, GroupName, ProfileName
							FROM TOControl_Profile WITH (NOLOCK)
							WHERE Sporttype = ct.sporttype
							)p
		)pf	
		LEFT JOIN @temp_ tmp ON tmp.custid = pf.custid AND tmp.matchid = pf.matchid AND tmp.ProfileID = pf.ProfileID AND tmp.IsGroupHeadLine = pf.IsGroupHeadline
		LEFT JOIN dbo.TOControl_Setting t WITH (NOLOCK) ON t.custid = pf.custid AND t.matchid = pf.matchid AND t.ProfileID = pf.ProfileID AND t.IsGroupHeadLine = pf.IsGroupHeadline
		INNER JOIN @MatchList m ON pf.matchid = m.matchid
		INNER JOIN dbo.exchange e WITH(NOLOCK) ON pf.currency = e.exchangeid
	
	SET @currentDate = GETDATE()
	
	INSERT INTO TOControl_Setting_History( CustID, Matchid, MaxTurnover, HouseTurnover,TotalTurnOver, PercentLevel, IsGroupHeadLine, ProfileID, NotifiedPercentValue, ModifiedDate)
	SELECT DISTINCT t.CustID
		   ,t.matchid
		   ,t.MaxTurnOver
		   ,t.HouseTurnover
		   ,t.TotalTurnOver
		   ,t.PercentLevel
		   ,t.IsGroupHeadLine
		   ,t.ProfileID
		   ,tmp.nlevel
		   ,@currentDate ModifiedDate
	FROM dbo.TOControl_Setting t WITH(NOLOCK)
	INNER JOIN @temp_ tmp
		ON t.matchid = tmp.matchid AND t.custid = tmp.custid AND t.IsGroupHeadLine = tmp.IsGroupHeadline AND t.ProfileID = tmp.ProfileID
	INNER JOIN TOControl_Profile p WITH (NOLOCK) ON t.ProfileID = p.ProfileID
	INNER JOIN @MatchList m ON t.matchid = m.matchid
	INNER JOIN dbo.exchange e WITH(NOLOCK) ON tmp.currency = e.exchangeid
	OUTER APPLY (
		SELECT TOP 1 h.CustID, h.MaxTurnover, h.IsGroupHeadLine, h.ProfileID, h.Matchid, h.NotifiedPercentValue
		FROM dbo.TOControl_Setting_History h WITH(NOLOCK)
		WHERE t.CustID = h.custid AND t.matchid = h.matchid AND  t.IsGroupHeadLine = h.IsGroupHeadline AND t.ProfileID = h.ProfileID 
		ORDER BY h.LogID DESC
	)tab
	WHERE  1 =  CASE WHEN tab.CustId  IS NULL THEN 1
					 WHEN tab.CustID IS NOT NULL AND t.MaxTurnOver <> tab.MaxTurnover THEN 1
					 WHEN tab.CustID IS NOT NULL AND t.MaxTurnOver = tab.MaxTurnover and tmp.nlevel <> tab.NotifiedPercentValue THEN 1
					ELSE 0 END
		
	DROP TABLE #Setting_tmp
END
GO

