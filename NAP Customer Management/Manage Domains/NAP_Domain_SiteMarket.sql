/*<info serverAlias="DBGLOB-GlobCustDB" executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROC [dbo].[NAP_Domain_SiteMarket]
AS
/*
	Created: 20231013@Tacy
	Task: Mapping Site and Market Code
	DB: DBGLOB-GlobCustDB
	
	Revisions:
		- 20231013@Tacy: Create SP [RedmineID: #194024]
		- 20250120@Tacy: Move to GlobCustDB [RedmineID: #216870]
*/
BEGIN
	SELECT siteid, site, SiteLabel
	, CASE	WHEN site IN ('BEST-ODDS','XYZBET')	THEN 'All'
			WHEN site IN ('611111')				THEN 'China'
			WHEN site IN ('IMBC')				THEN 'India'
			WHEN site IN ('IBCIndo','INDO')		THEN 'Indonesia'
			WHEN site IN ('JPNIBC')				THEN 'Japan'
			WHEN site IN ('KORIBC')				THEN 'Korea'
			WHEN site IN ('222223','222225','222227','222229','722222','733333') THEN 'Malaysia'
			WHEN site IN ('76666B','766666','7aa666') THEN 'Myanmmar'
			WHEN site IN ('777777')				THEN '777'
			WHEN site IN ('755555','7a5555')	THEN 'Thai'
			WHEN SiteLabel IN ('789y')			THEN '789y'
	END AS MarketCode
	FROM Site WITH (NOLOCK)
	WHERE isDeposit=0 AND isActive=1
	AND site<>'CN88'
	ORDER BY SiteLabel, MarketCode, site
END
GO