/*<info serverAlias="DBONUSER-ON_USER"></info>*/
/*
	Created: 20230323@Malcolm
	Task : Create new tables for Concurrent Online Users [RedmineID: #183462]
	DB: DBONUSER/ON_USER
*/
CREATE TABLE dbo.ConcurrentOnlineUserDetail
(
	CreatedDate			 DATETIME
	,Siteid				 INT
	,RoleId				  TINYINT
	,RealUserCount		  INT
	,TestingUserCount	  INT
	,CONSTRAINT PK_ConcurrentOnlineUserDetail PRIMARY KEY CLUSTERED (CreatedDate, Siteid, RoleId)	
)
GO

CREATE TABLE dbo.ConcurrentOnlineUserDaily
(
	CaptureDate			DATE
	,SiteLabel			VARCHAR(50)
	,Siteid				INT
	,RoleId				TINYINT
	,RealUserCount		INT
	,TestingUserCount	INT
	,GroupingType		TINYINT
)
GO

CREATE CLUSTERED INDEX CIX_CaptureDate ON dbo.ConcurrentOnlineUserDaily (CaptureDate)
GO

CREATE TABLE dbo.ConcurrentOnlineUserHourly
(
	CaptureDate			DATE
	,[Hour]				SMALLINT
	,SiteLabel			VARCHAR(50)
	,SiteId				INT
	,RoleId				TINYINT
	,RealUserCount		INT
	,TestingUserCount	INT
	,GroupingType		TINYINT
)
GO

CREATE CLUSTERED INDEX CIX_CaptureDate ON dbo.ConcurrentOnlineUserHourly (CaptureDate)
GO

