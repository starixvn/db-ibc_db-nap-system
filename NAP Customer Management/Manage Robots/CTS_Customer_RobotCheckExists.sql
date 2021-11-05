/*<info serverAlias="DBONUSER-ON_USER" executers="bodbAdminNet,bodbSPUNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[CTS_Customer_RobotCheckExist]
	@custids VARCHAR(MAX) = ''
AS
/*
		Created: 20210414@Johnson		 
		Task: Check robot accounts for CTS system
		DB: DBONUSER/ON_USER
		
		Revision:
			- 20210414@Johnson: Initial sp [redmine:#152250]
			- 20210907@Johnson: update robot rule [redmine:#161232]
			- 20211101@Johnson: Check robot with counter >10 [redmine:#163803]
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tblCust (custid INT PRIMARY KEY)
		
	INSERT INTO #tblCust(custid)
	SELECT val
	FROM strSplit(@custids,',')
	
	SELECT r.custid, r.counter
	FROM RobotUsers r WITH(NOLOCK)
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.custid = r.custid		
		LEFT JOIN bodb02.dbo.customer ag WITH(NOLOCK) ON c.recommend = ag.custid					
	WHERE 1 = CASE WHEN ISNULL(c.site,ag.site) = '611111' AND r.counter >=3 THEN 1
					WHEN c.srecommend IN (SELECT custid FROM bodb02.dbo.Dep_CustSuper (nolock))
						AND c.currency IN (6,13) 
						AND r.counter >= 3 THEN 1
					WHEN r.counter > 10 THEN 1
					ELSE 0 END
		AND r.custid IN (SELECT custid FROM #tblCust)			
	
	DROP TABLE #tblCust
END	