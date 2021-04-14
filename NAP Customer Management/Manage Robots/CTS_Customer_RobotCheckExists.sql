/*<info serverAlias="DBONUSER-ON_USER" executers="bodbAdminNet,bodbSPUNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[CTS_Customer_RobotCheckExist]
	@custids VARCHAR(MAX) = '',
	@RobotList VARCHAR(MAX) = '' OUTPUT
AS
/*
		Created: 20210414@Johnson		 
		Task: Check robot accounts for CTS system
		DB: DBONUSER/ON_USER
		
		Revision:
			- 20210414@Johnson: Initial sp [redmine:#152250]
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tblCust (custid INT PRIMARY KEY)
	SELECT @RobotList = ''
	
	INSERT INTO #tblCust(custid)
	SELECT val
	FROM strSplit(@custids,',')
	
	SELECT @RobotList = @RobotList + ',' + CAST(custid AS VARCHAR(10))
	FROM RobotUsers r WITH(NOLOCK)
	WHERE custid IN (SELECT custid FROM #tblCust)
		AND counter >=10
	
	SELECT @RobotList = STUFF(@RobotList,1,1,'')
	
	DROP TABLE #tblCust
END	