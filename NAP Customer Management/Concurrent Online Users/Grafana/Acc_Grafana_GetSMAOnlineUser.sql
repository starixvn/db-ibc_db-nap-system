/*<info serverAlias="DBWH-bodb_account" executers="vngrafana" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Acc_Grafana_GetSMAOnlineUser(
	 @FromDate SMALLDATETIME = NULL
	,@ToDate SMALLDATETIME = NULL
	,@Market VARCHAR(50) = NULL
	,@RoleID TINYINT = NULL
)
AS
/*
    Created: 20251114@Eden  
	Task : Alpha - Dashboard for Users Online [Redmine: #244197]
	DB: DBWH-bodb_account
  
	Revisions:
		- 20251114@Eden: Alpha - Dashboard for Users Online [Redmine: #244197] 

	Parameter's Explaination:
		@Market = : 789y, IBC, MBC (multiple choice)

		@RoleID = :
			2: Agent
			3: Master
			4: Super
			0: All

	Examples:
		EXEC Acc_Grafana_GetSMAOnlineUser 
			@FromDate = '2025-11-25 8:30:00.000',  
			@ToDate = '2025-11-25 8:45:00.000',
			@RoleId = 4,
			@Market = '789y'
		
	
*/
BEGIN
	CREATE TABLE #Site (SiteId INT PRIMARY KEY, SiteName NVARCHAR(50))

	--Convert input from UTC to GMT-4
	SELECT @FromDate = DATEADD(HOUR, -4, @FromDate),
		@ToDate = DATEADD(HOUR, -4, @ToDate)


	INSERT INTO #Site (SiteId, SiteName)
	SELECT SiteId, Site
	FROM bodb02.dbo.Site WITH(NOLOCK) 
	WHERE IsActive = 1 AND IsLicensee = 0
		AND SiteLabel IN ( SELECT value FROM string_split(@Market, ','))
	
	SELECT DATEADD(HOUR, 4,d.CreatedDate) AS [time], -- Convert to UTC
		s.SiteName  AS metric,
		SUM(d.UserCount) AS [value]
	FROM dbo.OnlineAgentDetail d WITH(NOLOCK)	
		INNER JOIN #Site s ON s.SiteId = d.SiteId
	WHERE CreatedDate BETWEEN @FromDate AND @ToDate
		AND (RoleId = @RoleID OR @RoleID = 0)
	GROUP BY d.CreatedDate, s.SiteName
	ORDER BY d.CreatedDate ASC, s.SiteName ASC

	DROP TABLE #Site
END
GO