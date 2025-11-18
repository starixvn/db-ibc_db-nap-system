/*<info serverAlias="DBCUST-CUSTDB" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_TOControl_GetSiteByMarket](@Market TINYINT) 
RETURNS TABLE
AS
/*
    Created: 20251118@Johnson
    Task: TO Control - Get site by market 
    DB: DBCUST/CUSTDB
    
    Revisions:
        - 20251118@Johnson: TO Monitor Control By League Group - Get site by market [Redmine: 243977]
*/
RETURN (SELECT SiteID, Site
        FROM site WITH(NOLOCK)
        WHERE isDeposit = 0 and isActive = 1
            AND (
                (@Market = 1 AND Site IN ('722222','733333','222223')) OR -- Malay
                (@Market = 2 AND SiteLabel = '789y') OR -- 789y
                (@Market = 3 AND SiteLabel <> '789y' AND Site NOT IN ('722222','733333','222223','CN88','Hedging','Special'))-- Others
            )
        )
