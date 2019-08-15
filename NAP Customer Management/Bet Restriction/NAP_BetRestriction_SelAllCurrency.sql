/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_SelAllCurrency]
AS
/*
	Created: 20190815@Eden
	Task : Get Site List
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]

	Example: 
	EXEC NAP_BetRestriction_SelAllCurrency 

	
	*/
BEGIN
		SELECT exchangeid,currency
		FROM dbo.exchange WITH(NOLOCK)
END
GO


