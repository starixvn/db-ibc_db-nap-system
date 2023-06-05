/*<info serverAlias="DBONUSER-ON_USER" executers="bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Age_Rpt_ConcurrentOnlineUserDetail_Sel
AS
/*
	Created: 20230323@Malcolm
	Task : Get Concurrent Online Users Detail [RedmineID: #183462]
	DB: DBONUSER/ON_USER

	Revisions:
		- 20230323@Malcolm: Initial SPs [redmine:#183462]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @CurrentDate DATETIME = DATEADD(HOUR, 12, GETDATE())

	CREATE TABLE #Site (SiteId INT PRIMARY KEY, SiteName NVARCHAR(50), SiteLabel VARCHAR(50))

	INSERT INTO #Site (SiteId, SiteName, SiteLabel)
	SELECT SiteId, Site, SiteLabel
	FROM bodb02.dbo.Site WITH(NOLOCK) 
	WHERE SiteLabel IS NOT NULL AND IsActive = 1 AND IsLicensee = 0
	
	SELECT 
		s.SiteId
		,c.RoleId
		,COUNT(CASE WHEN c.Currency <> 20 THEN 1 ELSE NULL END) AS RealUserCount
		,COUNT(CASE WHEN c.Currency = 20 THEN 1 ELSE NULL END) AS TestingUserCount
		,@CurrentDate AS CreatedDate
	FROM dbo.On_User_Agent a WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.CustId = a.CustId
		INNER JOIN #Site s ON s.SiteName = c.Site
	WHERE a.ServerId <> 0 AND a.subaccid >= 0
	GROUP BY s.SiteId, c.RoleId

	DROP TABLE #Site
END