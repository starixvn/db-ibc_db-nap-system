/*<info serverAlias="DBONUSER-ON_USER" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Age_Rpt_ConcurrentOnlineUser 
(
	@ReportType TINYINT
	,@FromDate  DATE = NULL
	,@ToDate    DATE = NULL
	,@IsTest	BIT = 0
)
AS
/*
	Created: 20230323@Malcolm
	Task : Get Concurrent Online Users [RedmineID: #183462]
	DB: DBONUSER/ON_USER

	Revisions:
		- 20230323@Malcolm: Initial SPs [redmine:#183462]

	Param's Explanation:
		@ReportType = 1: Instant Data Report
					= 2: Hourly Report
					= 3: Daily Report
*/
BEGIN
	SET NOCOUNT ON
	
	IF @ToDate >= CONVERT(DATE, DATEADD(HOUR, 12, GETDATE()))
		SET @ToDate = CONVERT(DATE, DATEADD(HOUR, 12, GETDATE()))

	CREATE TABLE #Site (SiteId INT PRIMARY KEY, SiteName NVARCHAR(50), SiteLabel NVARCHAR(50))

	INSERT INTO #Site (SiteId, SiteName, SiteLabel)
	SELECT SiteId, Site, SiteLabel
	FROM bodb02.dbo.Site WITH(NOLOCK) 
	WHERE SiteLabel IS NOT NULL AND IsActive = 1 AND IsLicensee = 0

	CREATE TABLE #Result
	(
		Grouping_SiteLabel	TINYINT
		,Grouping_SiteName	TINYINT
		,Grouping_SiteId	TINYINT
		,Grouping_RoleId	TINYINT
		,[Date]				DATE
		,[Hour]				SMALLINT	
		,SiteLabel			VARCHAR(50)
		,SiteName			NVARCHAR(50)
		,RoleName			NVARCHAR(10)
		,SiteId				INT
		,RoleId				TINYINT
		,RealUserCount		INT
		,TestingUserCount	INT
		,GroupingType		TINYINT
	)

	CREATE TABLE #UncalResult
	(
		Grouping_CreatedDate TINYINT
		,Grouping_SiteLabel	 TINYINT
		,Grouping_SiteId	 TINYINT
		,Grouping_RoleId	 TINYINT
		,CreatedDate		 DATETIME
		,SiteLabel			 VARCHAR(50)
		,SiteId				 INT
		,RoleId				 TINYINT
		,RealUserCount		 INT
		,TestingUserCount	 INT
	)

	CREATE TABLE #UnSumResult 
	(
		Grouping_Date		TINYINT
		,Grouping_Hour		TINYINT
		,Grouping_SiteLabel TINYINT
		,Grouping_SiteId	TINYINT
		,Grouping_RoleId	TINYINT
		,[Date]				DATE
		,[Hour]				SMALLINT
		,SiteLabel			VARCHAR(50)
		,SiteId				INT
		,RoleId				TINYINT
		,RealUserCount		INT
		,TestingUserCount	INT
	)

	IF @ReportType = 1 
	BEGIN
		INSERT INTO #Result 
		(
			Grouping_SiteLabel
			,Grouping_SiteName
			,Grouping_RoleId
			,SiteLabel
			,SiteName
			,RoleName
			,RealUserCount
			,TestingUserCount
		)
		SELECT 
			GROUPING(s.SiteLabel)	AS Grouping_SiteLabel
			,GROUPING(s.SiteName)	AS Grouping_SiteName
			,GROUPING(c.RoleId)		AS Grouping_RoleId
			,s.SiteLabel
			,s.SiteName
			,MAX(CASE c.RoleId WHEN 2 THEN 'Agent'
							   WHEN 3 THEN 'Master'
							   WHEN 4 THEN 'Super'
				 ELSE NULL END)		AS RoleName
			,COUNT(CASE WHEN c.Currency <> 20 THEN  1 ELSE NULL END) AS [RealUserCount]
			,COUNT(CASE WHEN c.Currency = 20 THEN  1 ELSE NULL END) AS [TestingUserCount]
		FROM dbo.On_User_Agent a WITH(NOLOCK)
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.CustId = a.CustId
			INNER JOIN #Site s ON s.SiteName = c.Site
		WHERE a.ServerId <> 0 AND a.subaccid >= 0
		GROUP BY
			GROUPING SETS 
			(
				(s.SiteLabel)
				,(c.RoleId)
				,(s.SiteLabel, s.SiteName)
				,(s.SiteLabel, s.SiteName, c.RoleId)
				,(s.SiteLabel, c.RoleId)
				
			)

		UPDATE r
			SET r.RoleName = NULL
		FROM #Result r
		WHERE Grouping_RoleId = 1

		;WITH CTE AS
		(
			SELECT
				SUM(CASE WHEN RoleName = 'Super'  THEN CASE WHEN @IsTest = 0 THEN RealUserCount ELSE TestingUserCount END ELSE 0 END) AS [Super]
				,SUM(CASE WHEN RoleName = 'Master' THEN CASE WHEN @IsTest = 0 THEN RealUserCount ELSE TestingUserCount END ELSE 0 END) AS [Master]
				,SUM(CASE WHEN RoleName = 'Agent'  THEN CASE WHEN @IsTest = 0 THEN RealUserCount ELSE TestingUserCount END ELSE 0 END) AS [Agent]
			FROM #Result
			WHERE Grouping_RoleId = 0 AND Grouping_SiteLabel = 1 AND Grouping_SiteName = 1
		)
		SELECT [Super], [Master], [Agent]
		FROM CTE
		WHERE [Super] > 0 OR [Master] > 0 OR [Agent] > 0

		;WITH CTE AS
		(
			SELECT
				SiteLabel
				,SUM(CASE WHEN Grouping_RoleId = 1 THEN CASE WHEN @IsTest = 0 THEN RealUserCount ELSE TestingUserCount END ELSE 0 END) AS Total
				,SUM(CASE WHEN Grouping_RoleId = 0 AND RoleName = 'Super'  THEN CASE WHEN @IsTest = 0 THEN RealUserCount ELSE TestingUserCount END ELSE 0 END) AS [Super]
				,SUM(CASE WHEN Grouping_RoleId = 0 AND RoleName = 'Master' THEN CASE WHEN @IsTest = 0 THEN RealUserCount ELSE TestingUserCount END ELSE 0 END) AS [Master]
				,SUM(CASE WHEN Grouping_RoleId = 0 AND RoleName = 'Agent'  THEN CASE WHEN @IsTest = 0 THEN RealUserCount ELSE TestingUserCount END ELSE 0 END) AS [Agent]
			FROM #Result 
			WHERE Grouping_SiteLabel = 0  AND Grouping_SiteName = 1
			GROUP BY SiteLabel
		)
		SELECT SiteLabel, Total, [Super], [Master], [Agent]
		FROM CTE
		WHERE Total > 0
		ORDER BY SiteLabel

		;WITH CTE AS
		(
			SELECT
				SiteLabel
				,SiteName
				,SUM(CASE WHEN Grouping_RoleId = 1 THEN CASE WHEN @IsTest = 0 THEN RealUserCount ELSE TestingUserCount END ELSE 0 END) AS Total
				,SUM(CASE WHEN Grouping_RoleId = 0 AND RoleName = 'Super'  THEN CASE WHEN @IsTest = 0 THEN RealUserCount ELSE TestingUserCount END ELSE 0 END) AS [Super]
				,SUM(CASE WHEN Grouping_RoleId = 0 AND RoleName = 'Master' THEN CASE WHEN @IsTest = 0 THEN RealUserCount ELSE TestingUserCount END ELSE 0 END) AS [Master]
				,SUM(CASE WHEN Grouping_RoleId = 0 AND RoleName = 'Agent'  THEN CASE WHEN @IsTest = 0 THEN RealUserCount ELSE TestingUserCount END ELSE 0 END) AS [Agent]
			FROM #Result 
			WHERE Grouping_SiteLabel = 0  AND Grouping_SiteName = 0
			GROUP BY SiteLabel, SiteName
		)
		SELECT SiteLabel, SiteName, Total, [Super], [Master], [Agent]
		FROM CTE
		WHERE Total > 0
		ORDER BY SiteLabel, SiteName

	END
	ELSE 
	BEGIN
		DECLARE @MaxDate DATE, @tmpFromDate DATE

		SELECT @MaxDate = MAX(CaptureDate) FROM dbo.ConcurrentOnlineUserDaily WITH(NOLOCK)

		IF @MaxDate  < @ToDate OR @MaxDate IS NULL
		BEGIN

			IF @MaxDate IS NULL
				SET @MaxDate = DATEADD(DAY, -1, @FromDate)

			INSERT INTO #UncalResult 
			(
				Grouping_CreatedDate
				,Grouping_SiteLabel
				,Grouping_SiteId
				,Grouping_RoleId
				,CreatedDate
				,SiteLabel
				,SiteId
				,RoleId
				,RealUserCount
				,TestingUserCount
			)
			SELECT 
				GROUPING(d.CreatedDate)				AS Grouping_CreatedDate
				,GROUPING(s.SiteLabel)				AS Grouping_SiteLabel
				,GROUPING(s.SiteId)					AS Grouping_SiteId
				,GROUPING(d.RoleId)					AS Grouping_RoleId
				,d.CreatedDate						AS CreatedDate
				,s.SiteLabel						AS SiteLabel
				,s.SiteId							AS SiteId
				,d.RoleId							AS RoleId
				,SUM(RealUserCount)					AS RealUserCount
				,SUM(TestingUserCount)				AS RealUserCount
			FROM dbo.ConcurrentOnlineUserDetail d WITH(NOLOCK)	
				INNER JOIN #Site s ON s.SiteId = d.SiteId
			WHERE CreatedDate >= DATEADD(DAY, 1, @MaxDate) AND CreatedDate < DATEADD(DAY, 1, @ToDate)
			GROUP BY 
				GROUPING SETS
				(
					(d.CreatedDate)
					,(d.CreatedDate, s.SiteLabel)
					,(d.CreatedDate, s.SiteLabel, s.SiteId)
					,(d.CreatedDate, s.siteLabel, s.SiteId, d.RoleId)
				)		 

			INSERT INTO #UnSumResult 
			(
				Grouping_Date
				,Grouping_Hour
				,Grouping_SiteLabel
				,Grouping_SiteId
				,Grouping_RoleId
				,[Date]
				,[Hour]
				,SiteLabel
				,SiteId
				,RoleId
				,RealUserCount
				,TestingUserCount
			)
			SELECT 
				GROUPING(CONVERT(DATE, ur.CreatedDate)) AS Grouping_Date
				,GROUPING(DATEPART(HH, ur.CreatedDate)) AS Grouping_Hour
				,GROUPING(ur.SiteLabel)					AS Grouping_SiteLabel
				,GROUPING(ur.SiteId)					AS Grouping_SiteId
				,GROUPING(ur.RoleId)					AS Grouping_RoleId
				,CONVERT(DATE, ur.CreatedDate)			AS [Date]
				,DATEPART(HH, ur.CreatedDate)			AS [Hour]
				,ur.SiteLabel							AS SiteLabel
				,ur.SiteId								AS SiteName
				,ur.RoleId								AS RoleId
				,MAX(ur.RealUserCount)					AS RealUserCount
				,MAX(ur.TestingUserCount)				AS TestingUserCount
			FROM #UncalResult ur
			GROUP BY 
				GROUPING SETS 
				(
					(CONVERT(DATE, ur.CreatedDate),  DATEPART(HH, ur.CreatedDate), ur.SiteLabel, ur.SiteId, ur.RoleId)
					,(CONVERT(DATE, ur.CreatedDate), DATEPART(HH, ur.CreatedDate), ur.SiteLabel, ur.SiteId)
					,(CONVERT(DATE, ur.CreatedDate), DATEPART(HH, ur.CreatedDate), ur.SiteLabel)
					,(CONVERT(DATE, ur.CreatedDate), DATEPART(HH, ur.CreatedDate))
					,(CONVERT(DATE, ur.CreatedDate), ur.SiteLabel, ur.SiteId, ur.RoleId)
					,(CONVERT(DATE, ur.CreatedDate), ur.SiteLabel, ur.SiteId)
					,(CONVERT(DATE, ur.CreatedDate), ur.SiteLabel)
					,(CONVERT(DATE, ur.CreatedDate))
				)

			DELETE r
			FROM #UnSumResult r
			WHERE 
				(Grouping_Date = 0 AND [Date] IS NULL)
				OR (Grouping_Hour = 0 AND [Hour] IS NULL)
				OR (Grouping_SiteLabel = 0 AND SiteLabel IS NULL)
				OR (Grouping_SiteId = 0 AND SiteId IS NULL)
				OR (Grouping_RoleId = 0 AND RoleId IS NULL)
		END

		IF @ReportType = 2
		BEGIN		
			INSERT INTO #Result 
			(
				[Hour]
				,siteLabel
				,SiteId
				,RoleId
				,RealUserCount
				,TestingUserCount
				,GroupingType
			)
			SELECT 
				r.[Hour]
				,r.SiteLabel
				,r.SiteId
				,r.RoleId
				,r.RealUserCount
				,r.TestingUserCount
				,CASE WHEN r.Grouping_RoleId	= 0	THEN 3
					  WHEN r.Grouping_SiteId	= 0	THEN 2
					  WHEN r.Grouping_SiteLabel = 0 THEN 1
					  WHEN r.Grouping_Hour = 0		THEN 4
				ELSE NULL END AS [GroupingType]
			FROM #UnSumResult r
			WHERE r.Grouping_Hour = 0 AND [Date] = @Todate

			IF NOT EXISTS (SELECT 1 FROM #Result)
			BEGIN
				INSERT INTO #Result 
				(
					[Hour]
					,siteLabel
					,SiteId
					,RoleId
					,RealUserCount
					,TestingUserCount
					,GroupingType
				)
				SELECT 
					[Hour]
					,SiteLabel
					,SiteId
					,RoleId
					,RealUserCount
					,TestingUserCount
					,GroupingType
				FROM dbo.ConcurrentOnlineUserHourly h WITH(NOLOCK)
				WHERE h.CaptureDate = @ToDate
			END

			UPDATE r
				SET r.RoleName = CASE r.RoleId WHEN 2 THEN 'Agent' 
											   WHEN 3 THEN 'Master'
											   WHEN 4 THEN 'Super'
								  ELSE r.RoleName END
					,r.SiteName = ISNULL(s.Site, r.SiteName)
			FROM #Result r
				LEFT JOIN bodb02.dbo.Site s WITH(NOLOCK) ON s.SiteId = r.SiteId
	
			--Return Data for Hourly
			;WITH CTE AS
			(
				SELECT 
					r.[Hour]
					,CASE WHEN @IsTest = 0 THEN r.RealUserCount ELSE r.TestingUserCount END AS UserCount 
			    FROM #Result r 
				WHERE [GroupingType] = 4
			)
			SELECT [Hour], UserCount
			FROM CTE
			WHERE UserCount > 0
			ORDER BY [Hour]

			;WITH CTE AS 
			(
				SELECT 
					r.[Hour]
					,r.SiteLabel
					,CASE WHEN @IsTest = 0 THEN r.RealUserCount ELSE r.TestingUserCount END AS UserCount 
				FROM #Result r 
				WHERE [GroupingType] = 1 
				
			)
			SELECT [Hour], SiteLabel, UserCount
			FROM CTE
			WHERE UserCount > 0
			ORDER BY [Hour], SiteLabel		

			;WITH CTE AS
			(
				SELECT 
					r.[Hour]
					,r.SiteLabel
					,r.SiteName
					,CASE WHEN @IsTest = 0 THEN r.RealUserCount ELSE r.TestingUserCount END AS UserCount 
				FROM #Result r 
				WHERE [GroupingType] = 2 

			)
			SELECT [Hour], SiteLabel, SiteName, UserCount
			FROM CTE
			WHERE UserCount > 0
			ORDER BY [Hour], SiteLabel, SiteName

			;WITH CTE AS
			(
				SELECT 
					r.[Hour]
					,r.SiteLabel
					,r.SiteName
					,r.RoleName
					,CASE WHEN @IsTest = 0 THEN r.RealUserCount ELSE r.TestingUserCount END AS UserCount 
				FROM #Result r 
				WHERE [GroupingType] = 3 
			)
			SELECT [Hour], SiteLabel, SiteName, RoleName, UserCount
			FROM CTE
			WHERE UserCount > 0
			ORDER BY [Hour], SiteLabel, SiteName, RoleName
			
		END
		ELSE IF @ReportType = 3
		BEGIN		
			INSERT INTO #Result 
			(
				[Date]
				,siteLabel
				,Siteid
				,RoleId
				,RealUserCount
				,TestingUserCount
				,GroupingType
			)
			SELECT 
				r.[Date]
				,r.SiteLabel
				,r.SiteId
				,r.RoleId
				,r.RealUserCount
				,r.TestingUserCount
				,CASE WHEN r.Grouping_RoleId	  = 0	THEN 3
					  WHEN r.Grouping_SiteId	  = 0	THEN 2
					  WHEN r.Grouping_SiteLabel   = 0   THEN 1
				ELSE 4 END AS [GroupingType]
			FROM #UnSumResult r
			WHERE r.[Date] >= DATEADD(DAY, 1, @MaxDate) AND r.[Date] < DATEADD(DAY, 1, @ToDate) AND Grouping_Hour = 1

			IF @@ROWCOUNT > 0
			BEGIN
				SELECT @ToDate = @MaxDate
			END

			INSERT INTO #Result 
			(
				[Date]
				,siteLabel
				,Siteid
				,RoleId
				,RealUserCount
				,TestingUserCount
				,GroupingType
			)
			SELECT 
				c.CaptureDate
				,c.Sitelabel
				,c.Siteid 
				,c.RoleId
				,c.RealUserCount
				,c.TestingUserCount
				,c.GroupingType
			FROM dbo.ConcurrentOnlineUserDaily c WITH(NOLOCK)
			WHERE c.CaptureDate >= @FromDate AND c.CaptureDate < DATEADD(DAY, 1, @ToDate)
			
			UPDATE r
				SET r.RoleName = CASE r.RoleId WHEN 2 THEN 'Agent' 
											   WHEN 3 THEN 'Master'
											   WHEN 4 THEN 'Super'
								  ELSE r.RoleName END
					,r.SiteName = ISNULL(s.Site, r.SiteName)
			FROM #Result r
				LEFT JOIN bodb02.dbo.Site s WITH(NOLOCK) ON s.SiteId = r.SiteId

			--Return data for Daily

			;WITH CTE AS
			(
				SELECT 
					r.[Date]
					,CASE WHEN @IsTest = 0 THEN r.RealUserCount ELSE r.TestingUserCount END AS UserCount 
				FROM #Result r 
				WHERE [GroupingType] = 4 
			)
			SELECT [Date], UserCount
			FROM CTE
			WHERE UserCount > 0
			ORDER BY [Date]

			;WITH CTE AS
			(
				SELECT 
					r.[Date]
					,r.SiteLabel
					,CASE WHEN @IsTest = 0 THEN r.RealUserCount ELSE r.TestingUserCount END AS UserCount 
				FROM #Result r 
				WHERE [GroupingType] = 1 
			)
			SELECT [Date], SiteLabel, UserCount
			FROM CTE
			WHERE UserCount > 0
			ORDER BY [Date], SiteLabel
			
			;WITH CTE AS
			(
				SELECT 
					r.[Date]
					,r.SiteLabel
					,r.SiteName
					,CASE WHEN @IsTest = 0 THEN r.RealUserCount ELSE r.TestingUserCount END AS UserCount 
				FROM #Result r 
				WHERE [GroupingType] = 2 
			)
			SELECT [Date], SiteLabel, SiteName, UserCount
			FROM CTE
			WHERE UserCount > 0
			ORDER BY [Date], SiteLabel, SiteName

			;WITH CTE AS
			(
				SELECT 
					r.[Date]
					,r.SiteLabel
					,r.SiteName
					,r.RoleName
					,CASE WHEN @IsTest = 0 THEN r.RealUserCount ELSE r.TestingUserCount END AS UserCount 
				FROM #Result r 
				WHERE [GroupingType] = 3 
				
			)
			SELECT [Date], SiteLabel, SiteName, RoleName, UserCount
			FROM CTE
			WHERE UserCount > 0
			ORDER BY [Date], SiteLabel, SiteName, RoleName
		END
	END

	DROP TABLE #Site
	DROP TABLE #Result
	DROP TABLE #UnSumResult
	DROP TABLE #UncalResult
END