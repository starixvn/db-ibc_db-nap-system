/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_BetRestriction_SelAllSite]
AS
/*
	Created: 20190815@Eden
	Task : Get Site List
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP 

	Example: 
	EXEC Acc_BetRestriction_SelAllSite 

	
	*/
BEGIN
		SELECT SiteID,Site
		FROM dbo.[Site] WITH(NOLOCK)
END
GO


