/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_BetRestriction_SelAllCurrency]
AS
/*
	Created: 20190815@Eden
	Task : Get Site List
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP 

	Example: 
	EXEC Acc_BetRestriction_SelAllCurrency 

	
	*/
BEGIN
		SELECT exchangeid,currency
		FROM dbo.exchange WITH(NOLOCK)
END
GO


