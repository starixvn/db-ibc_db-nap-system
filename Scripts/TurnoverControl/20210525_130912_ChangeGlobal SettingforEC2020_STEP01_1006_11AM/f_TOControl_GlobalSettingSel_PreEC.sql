/*<info serverAlias="DBCUST-CUSTDB" executers="" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_TOControl_GlobalSettingSel_PreEC]() 
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 20210601@July
    Task: TO Control - Support to add default TO setting for new direct customers
    DB: DBCUST/CUSTDB
    
    Revisions:
		- 20210601@July: Clone from function f_TOControl_GlobalSettingSel() [Redmine: #130912]

    Parameters Explanation:  
    
    Notes:
    + Soccer		:    Soccer global setting will be 300K MYR & 789Y SMA will be 200K USD.
    + Other Sports	:	150 K MYR
    
*/
RETURN (
	SELECT CAST(1 AS INT) ProfileID
	, CAST(1 AS SMALLINT) Sporttype
	, CAST('789y' AS NVARCHAR(50)) AS site
	, CAST(0 AS INT) ExchangeID
	, CAST(60000 AS MONEY) MaxTurnOver
	, CAST(3 AS INT) TOCurrency -- US$
	
	UNION ALL
	SELECT 2  ProfileID, 1 Sporttype, '789y'  Site,0 ExchangeID, 60000  MaxTurnover, 3  ToCurrency
	UNION ALL
	SELECT 3  ProfileID, 1 Sporttype, '789y'  Site,0 ExchangeID, 30000  MaxTurnover, 3  ToCurrency
	UNION ALL
	SELECT 4  ProfileID, 1 Sporttype, '789y'  Site,0 ExchangeID, 30000  MaxTurnover, 3  ToCurrency
	UNION ALL
	SELECT 5  ProfileID, 1 Sporttype, '789y'  Site, 0 ExchangeID,30000  MaxTurnover, 3  ToCurrency
	UNION ALL
	SELECT 6  ProfileID, 1 Sporttype, '789y'  Site,0 ExchangeID, 60000  MaxTurnover, 3  ToCurrency
	UNION ALL
	SELECT 7  ProfileID, 1 Sporttype, '789y'  Site,0 ExchangeID, 60000  MaxTurnover, 3  ToCurrency
	UNION ALL
	SELECT 8  ProfileID, 1 Sporttype, '789y'  Site,0 ExchangeID, 30000  MaxTurnover, 3  ToCurrency
	UNION ALL
	SELECT 9  ProfileID, 1 Sporttype, '789y'  Site,0 ExchangeID, 30000  MaxTurnover, 3  ToCurrency
	UNION ALL
	SELECT 10  ProfileID, 1 Sporttype, '789y'  Site,0 ExchangeID, 30000  MaxTurnover, 3  ToCurrency
	UNION ALL
	
	-- 789y UUS
	SELECT 1  ProfileID, 1  Sporttype, '789y'   Site,20  ExchangeID, 60000  MaxTurnover,20   ToCurrency
	UNION ALL
	SELECT 2  ProfileID, 1 Sporttype, '789y'  Site,20 ExchangeID, 60000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 3  ProfileID, 1 Sporttype, '789y'  Site,20 ExchangeID, 30000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 4  ProfileID, 1 Sporttype, '789y'  Site,20 ExchangeID, 30000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 5  ProfileID, 1 Sporttype, '789y'  Site, 20 ExchangeID,30000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 6  ProfileID, 1 Sporttype, '789y'  Site,20 ExchangeID, 60000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 7  ProfileID, 1 Sporttype, '789y'  Site,20 ExchangeID, 60000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 8  ProfileID, 1 Sporttype, '789y'  Site,20 ExchangeID, 30000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 9  ProfileID, 1 Sporttype, '789y'  Site,20 ExchangeID, 30000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 10  ProfileID, 1 Sporttype, '789y'  Site,20 ExchangeID, 30000  MaxTurnover, 20  ToCurrency
	UNION ALL
	
	-- OTHER SITE SPORTTYPE = 1

	SELECT 1  ProfileID, 1 Sporttype, ''  Site,0 ExchangeID, 100000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 2  ProfileID, 1 Sporttype, ''  Site,0 ExchangeID, 100000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 3  ProfileID, 1 Sporttype, ''  Site,0 ExchangeID, 50000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 4  ProfileID, 1 Sporttype, ''  Site,0 ExchangeID, 50000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 5  ProfileID, 1 Sporttype, ''  Site,0 ExchangeID, 50000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 6  ProfileID, 1 Sporttype, ''  Site,0 ExchangeID, 100000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 7  ProfileID, 1 Sporttype, ''  Site,0 ExchangeID, 100000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 8  ProfileID, 1 Sporttype, ''  Site, 0 ExchangeID,50000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 9  ProfileID, 1 Sporttype, ''  Site,0 ExchangeID, 50000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 10  ProfileID, 1 Sporttype, ''  Site,0 ExchangeID, 50000  MaxTurnover, 2  ToCurrency
	UNION ALL

	-- Other site for UUS, sporttype = 1
	SELECT 1  ProfileID, 1 Sporttype, ''  Site,20 ExchangeID, 100000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 2  ProfileID, 1 Sporttype, ''  Site,20 ExchangeID, 100000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 3  ProfileID, 1 Sporttype, ''  Site,20ExchangeID, 50000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 4  ProfileID, 1 Sporttype, ''  Site,20 ExchangeID, 50000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 5  ProfileID, 1 Sporttype, ''  Site,20 ExchangeID, 50000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 6  ProfileID, 1 Sporttype, ''  Site,20 ExchangeID, 100000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 7  ProfileID, 1 Sporttype, ''  Site,20 ExchangeID, 100000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 8  ProfileID, 1 Sporttype, ''  Site, 20 ExchangeID,50000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 9  ProfileID, 1 Sporttype, ''  Site,20 ExchangeID, 50000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 10  ProfileID, 1 Sporttype, ''  Site,20 ExchangeID, 50000  MaxTurnover, 20  ToCurrency
	UNION ALL

	-- OTHER SPORT ALL SITE SPORT ID = 99

	SELECT 11  ProfileID, 99 Sporttype, ''  Site,0 ExchangeID, 37500  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 12  ProfileID, 99 Sporttype, ''  Site,0 ExchangeID, 37500  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 13  ProfileID, 99 Sporttype, ''  Site,0 ExchangeID, 24000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 14  ProfileID, 99 Sporttype, ''  Site,0 ExchangeID, 24000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 15  ProfileID, 99 Sporttype, ''  Site,0 ExchangeID, 24000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 16  ProfileID, 99 Sporttype, ''  Site,0 ExchangeID, 37500  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 17  ProfileID, 99 Sporttype, ''  Site,0 ExchangeID, 37500  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 18  ProfileID, 99 Sporttype, ''  Site,0 ExchangeID, 24000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 19  ProfileID, 99 Sporttype, ''  Site,0 ExchangeID, 24000  MaxTurnover, 2  ToCurrency
	UNION ALL
	SELECT 20  ProfileID, 99 Sporttype, ''  Site,0 ExchangeID, 24000  MaxTurnover, 2  ToCurrency
   
    -- other sport, other site for UUS
    UNION ALL
    SELECT 11  ProfileID, 99 Sporttype, ''  Site,20 ExchangeID, 37500  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 12  ProfileID, 99 Sporttype, ''  Site,20 ExchangeID, 37500  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 13  ProfileID, 99 Sporttype, ''  Site,20 ExchangeID, 24000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 14  ProfileID, 99 Sporttype, ''  Site,20 ExchangeID, 24000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 15  ProfileID, 99 Sporttype, ''  Site,20 ExchangeID, 24000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 16  ProfileID, 99 Sporttype, ''  Site,20 ExchangeID, 37500  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 17  ProfileID, 99 Sporttype, ''  Site,20 ExchangeID, 37500  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 18  ProfileID, 99 Sporttype, ''  Site,20 ExchangeID, 24000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 19  ProfileID, 99 Sporttype, ''  Site,20 ExchangeID, 24000  MaxTurnover, 20  ToCurrency
	UNION ALL
	SELECT 20  ProfileID, 99 Sporttype, ''  Site,20 ExchangeID, 24000  MaxTurnover, 20  ToCurrency

)
GO

