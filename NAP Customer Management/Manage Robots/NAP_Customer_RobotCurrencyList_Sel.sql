/*<info serverAlias="DBONUSER-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Customer_RobotCurrencyList_Sel]	
AS
/*
		Created: Johnson
		Date: 2019-09-27
		Task: select robot accounts new version
		DB: DBONUSER/bodb02
		
		Revision:
			- 20190927@Johnson: Initial sp [redmine:#119714]
		Parameter's Explanation:			
*/ 
BEGIN
	SET NOCOUNT ON
	
	SELECT exchangeid, currency
	FROM dbo.Exchange WITH(NOLOCK)
	WHERE currency NOT IN ('C','H')
END	
GO