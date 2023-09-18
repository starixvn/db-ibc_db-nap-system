/*<info serverAlias="DBONUSER-ON_USER" executers="bodbAdminNet,bodbSPUNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[CTS_Customer_RobotListSelByDate]
	@FromDate DATETIME,
	@ToDate DATETIME,
	@IsLicensee TINYINT
AS
/*
		Created: 20230918@Johnson		 
		Task: select robot accounts by date for CTS system
		DB: DBONUSER/ON_USER
		
		Revision:
			- 20230918@Johnson: Initial sp [redmine:#193708]
			
*/
BEGIN
	SET NOCOUNT ON
	
	;WITH T AS (
	SELECT r.custid, r.counter, RobotDate, CASE WHEN c.srecommend IN (SELECT custid FROM bodb02.dbo.Dep_CustSuper (nolock))	THEN 1 ELSE 0 END IsLicensee
	FROM RobotUsers r WITH(NOLOCK)
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.custid = r.custid		
		LEFT JOIN bodb02.dbo.customer ag WITH(NOLOCK) ON c.recommend = ag.custid					
	WHERE r.RobotDate BETWEEN @FromDate AND @ToDate	
		AND 1 = CASE WHEN ISNULL(c.site,ag.site) = '611111' AND r.counter >=3 THEN 1
					WHEN c.srecommend IN (SELECT custid FROM bodb02.dbo.Dep_CustSuper (nolock))
						AND c.currency IN (6,13) 
						AND r.counter >= 3 THEN 1
					WHEN r.counter > 10 THEN 1
					ELSE 0 END
	)
	SELECT * FROM T
	WHERE IsLicensee = CASE WHEN @IsLicensee IN (0,1) THEN @IsLicensee ELSE IsLicensee END
END			
