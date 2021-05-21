/*<info serverAlias="DBONUSER-ON_USER" executers="bodbAdminNet,bodbSPUNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[CTS_Customer_RobotListSel]
	@FromDate DATETIME,
	@creditSite VARCHAR(MAX) = ''
AS
/*
		Created: 20200911@Johnson		 
		Task: select robot accounts for CTS system
		DB: DBONUSER/ON_USER
		
		Revision:
			- 20200911@Johnson: Initial sp [redmine:#141416]
			- 20210517@Johnson: convert @FromDate to smalldatetime to fix issue datatype RobotUsers [redmine:#153617]
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpSite TABLE (site nVARCHAR(100))
	DECLARE @_fromDate SMALLDATETIME
	
	SELECT @_fromDate = CAST(DATEADD(SECOND,-30,@FromDate) as SMALLDATETIME)
	
	INSERT INTO @tmpSite(site)
	SELECT val
	FROM strSplit(@creditSite,',')
	
	SELECT r.custid, r.robotDate
	FROM RobotUsers r WITH(NOLOCK)
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.custid = r.custid		
		LEFT JOIN bodb02.dbo.customer ag WITH(NOLOCK) ON c.recommend = ag.custid					
	WHERE RobotDate >= @_fromDate
		AND r.counter >=10
		AND (ISNULL(NULLIF(c.site,''),ag.site) IN (SELECT site FROM @tmpSite)
			OR c.srecommend IN (SELECT custid FROM bodb02.dbo.Dep_CustSuper (nolock))
			)	
END			
