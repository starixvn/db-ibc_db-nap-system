/*<info serverAlias="DBCUST-CUSTDB" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_TOControl_GlobalSettingSel]() 
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 20171113@Helen
    Task: TO Control - Support to add default TO setting for new direct customers
    DB: DBCUST/CUSTDB
    
    Revisions:
		- 20171113@Helen: Create new [Redmine: 86052]
		- 20180509@Kan: Update new global setting for World Cup event [Redmine: 92010]
		  + 789y site: equivalent to USD 200,000
		  + Other sites: equivalent to MYR 500,000
		- 20180706@Kan: Rollback new global setting to old value after World Cup event [Redmine: 97774]
		- 20190604@Helen: Implement Turnover Control for CN88 site [Redmine: 113233]
		- 20190712@Helen: Implement Turnover Control for CN88 site - Change Request [Redmine: 113233]
		- 20190913@Helen: Change Global setting [Redmine: 113472]
		- 20200114@Malcolm: Separate setting and notification into Live/Non-Live and bettypes [Redmine : #126348]
		- 20200120@Max: Support Separate setting and notification into Live/Non-Live major and minor bettypes [Redmine: #126841]
		- 20200524@July: Remove code 4H,4C,CN88 [Redmine: #130912] 
		- 20200611@July: Update MaxTurnover * N [Redmine: #130912] 

    Parameters Explanation:  
    
    Notes:
    + Soccer		:    Soccer global setting will be 300K MYR & 789Y SMA will be 200K USD.
    + Other Sports	:	150 K MYR
    
*/
RETURN (
	/*Rule a: Add 200% of the current TO (current TO * 300%) for the following sites: 789y, 755555, Indo, IBCIndo*/

	--789y
	SELECT ProfileID, Sporttype, '789y' AS site , ExchangeID, MaxTurnOver * 3  AS MaxTurnOver, TOCurrency
	FROM dbo.f_TOControl_GlobalSettingSel_PreEC ()
	WHERE site = '789y'
	UNION ALL
	--755555
	SELECT ProfileID, Sporttype, '755555' AS site, ExchangeID, MaxTurnOver * 3 AS MaxTurnOver, TOCurrency
	FROM dbo.f_TOControl_GlobalSettingSel_PreEC ()
	WHERE site = ''
	UNION ALL
	--Indo
	SELECT ProfileID, Sporttype, 'Indo' AS site, ExchangeID, MaxTurnOver * 3 AS MaxTurnOver, TOCurrency
	FROM dbo.f_TOControl_GlobalSettingSel_PreEC ()
	WHERE site = ''
	UNION ALL
	--IBCIndo
	SELECT ProfileID, Sporttype, 'IBCIndo' AS site, ExchangeID, MaxTurnOver * 3 AS MaxTurnOver, TOCurrency
	FROM dbo.f_TOControl_GlobalSettingSel_PreEC ()
	WHERE site = ''
	UNION ALL

	/*Rule b: Add 150% of the current TO (current TO * 250%) for the following sites: 733333,72222,222223*/

	--733333
	SELECT ProfileID, Sporttype, '733333' AS site, ExchangeID, MaxTurnOver * 2.5 AS MaxTurnOver, TOCurrency
	FROM dbo.f_TOControl_GlobalSettingSel_PreEC ()
	WHERE site = ''
	UNION ALL
	--72222
	SELECT ProfileID, Sporttype, '72222' AS site, ExchangeID, MaxTurnOver * 2.5 AS MaxTurnOver, TOCurrency
	FROM dbo.f_TOControl_GlobalSettingSel_PreEC ()
	WHERE site = ''
	UNION ALL
	--222223
	SELECT ProfileID, Sporttype, '222223' AS site, ExchangeID, MaxTurnOver * 2.5 AS MaxTurnOver, TOCurrency
	FROM dbo.f_TOControl_GlobalSettingSel_PreEC ()
	WHERE site = ''
	UNION ALL

	/*Rule c: Add 100% of the current TO (current TO * 200%) for the following sites: 76666B, 7aa666*/

	--76666B
	SELECT ProfileID, Sporttype, '76666B' AS site, ExchangeID, MaxTurnOver * 2 AS MaxTurnOver, TOCurrency
	FROM dbo.f_TOControl_GlobalSettingSel_PreEC ()
	WHERE site = ''
	UNION ALL
	--7aa666
	SELECT ProfileID, Sporttype, '7aa666' AS site, ExchangeID, MaxTurnOver * 2 AS MaxTurnOver, TOCurrency
	FROM dbo.f_TOControl_GlobalSettingSel_PreEC ()
	WHERE site = ''
	UNION ALL

	/*Rule e: Add 200% of the current TO (current TO * 300%) for the site 611111 except the 79 supers */
	--611111 
	SELECT ProfileID, Sporttype, '611111' AS site, ExchangeID, MaxTurnOver * 3 AS MaxTurnOver, TOCurrency
	FROM dbo.f_TOControl_GlobalSettingSel_PreEC ()
	WHERE site = ''
	UNION ALL

	/* New site*/
	SELECT ProfileID, Sporttype, '' AS site, ExchangeID, MaxTurnOver AS MaxTurnOver, TOCurrency
	FROM dbo.f_TOControl_GlobalSettingSel_PreEC ()
	WHERE site = ''
)
GO

