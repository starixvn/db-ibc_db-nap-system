/*<info serverAlias="DBONUSER-ON_USER" executers="bodbAdminNet,bodbSPUNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[CTS_Customer_RobotListSel]
	@LastTstamp BIGINT,	
	@MaxTstamp 	BIGINT = 0 OUTPUT
AS
/*
		Created: 20200911@Johnson		 
		Task: select robot accounts for CTS system
		DB: DBONUSER/ON_USER
		
		Revision:
			- 20200911@Johnson: Initial sp [redmine:#141416]
			- 20210517@Johnson: convert @FromDate to smalldatetime to fix issue datatype RobotUsers [redmine:#153617]
			- 20210907@Johnson: get robot list by last tstamp [redmine:#161232]
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @_tstamp TIMESTAMP 
	
	SELECT @_tstamp = CAST(@LastTstamp AS TIMESTAMP)
		
	SELECT r.custid, r.counter, CAST(r.tstamp as BIGINT) AS tstamp
	INTO #Result
	FROM RobotUsers r WITH(NOLOCK)
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.custid = r.custid		
		LEFT JOIN bodb02.dbo.customer ag WITH(NOLOCK) ON c.recommend = ag.custid					
	WHERE r.tstamp > @_tstamp		
		AND 1 = CASE WHEN ISNULL(c.site,ag.site) = '611111' AND r.counter >=3 THEN 1
					WHEN c.srecommend IN (SELECT custid FROM bodb02.dbo.Dep_CustSuper (nolock))
						AND c.currency IN (6,13) 
						AND r.counter >= 3 THEN 1
					WHEN r.counter >= 10 THEN 1
					ELSE 0 END
		
	SELECT @MaxTstamp = ISNULL((SELECT MAX(tstamp)
	FROM #result),0)
	
	SELECT custid, counter 
	FROM #result
END			
