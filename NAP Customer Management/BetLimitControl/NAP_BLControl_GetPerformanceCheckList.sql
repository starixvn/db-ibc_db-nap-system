/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_GetPerformanceCheckList] 
AS
/*
	Created: 20200818@Eden
	Task : get customer list for Check Performance Licensee Job
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200818@Eden: Create New SP  [RedmineID: #139701]

	Parameter explanation:
	*/
BEGIN
	SELECT c.CustID 
	FROM BetLimitControlCustSetting c WITH(NOLOCK)
		INNER JOIN custinfo ci WITH(NOLOCK)
			ON c.CustID = ci.custid AND ci.roleid = 1
	WHERE c.BetLimitTypeID = 25 --New Account Bet Limit by Performance
END
GO


