/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROC [dbo].[NAP_Domain_Sel]
	 @System	VARCHAR(50)
	,@Site		VARCHAR(500)
	,@Status	VARCHAR(30)
	,@OfferType	VARCHAR(2)=''
	,@Remark	NVARCHAR(2000)=NULL
	,@Countries	VARCHAR(4000)=''
AS
/*
	Created: 20231013@Tacy
	Task: Get list domains
	DB: DBACC-bodb02
	
	Revisions:
		- 20231013@Tacy: Create SP [RedmineID: #194024]
		- 20250624@Johnson: offer Agency Cash Service [RedmineID: #231219]
	Param's Explanation:
		@Countries: '0' ~ ALL coutries and include null value
					''	~ Domain with none Restricted Countries

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tbSite TABLE (SiteID INT)
	DECLARE @tbSystem TABLE (System VARCHAR(20))
	DECLARE @tbCountries TABLE (CountryCode VARCHAR(10))
	DECLARE @tbDomains TABLE (DomainID INT PRIMARY KEY)

	INSERT INTO @tbSite (SiteID)
	SELECT TRIM(value) FROM STRING_SPLIT(@Site,',')
	WHERE TRIM(value)<>''

	INSERT INTO @tbSystem (System)
	SELECT TRIM(value) FROM STRING_SPLIT(@System,',')
	WHERE TRIM(value)<>''

	IF @Countries NOT IN ('','0') --ALL/NONE SELECTION
	BEGIN
		INSERT INTO @tbCountries (CountryCode)
		SELECT TRIM(value) FROM STRING_SPLIT(@Countries,',')
		WHERE TRIM(value)<>''

		INSERT INTO @tbDomains(DomainID)
		SELECT d.DomainID
		FROM DomainManagement d WITH (NOLOCK)
		--Filter System
		INNER JOIN @tbSystem ss ON ss.System=d.System
		--Filter Status
		CROSS APPLY (SELECT 1 AS val FROM STRING_SPLIT(@Status,',') t
						WHERE CAST(TRIM(t.value) AS INT)=d.Status) stt
		--Filter Site
		CROSS APPLY (SELECT CAST(TRIM(value) AS INT) AS SiteID FROM STRING_SPLIT(d.Site,',')) sd
		CROSS APPLY (SELECT TOP 1 d.Domain FROM @tbSite s
						WHERE s.SiteID=sd.SiteID) s
		--Filter Countries
		CROSS APPLY (SELECT CAST(TRIM(value) AS VARCHAR(30)) AS CountryCode FROM STRING_SPLIT(d.RestrictedCountries,',')) cd
		CROSS APPLY (SELECT TOP 1 d.Domain FROM @tbCountries c
						WHERE c.CountryCode=cd.CountryCode) c
		WHERE d.isDeleted=0
		GROUP BY d.DomainID
	END
	ELSE 
	BEGIN
		INSERT INTO @tbDomains(DomainID)
		SELECT d.DomainID
		FROM DomainManagement d WITH (NOLOCK)
		--Filter System
		INNER JOIN @tbSystem ss ON ss.System=d.System
		--Filter Status
		CROSS APPLY (SELECT 1 AS val FROM STRING_SPLIT(@Status,',') t
						WHERE CAST(TRIM(t.value) AS INT)=d.Status) stt
		--Filter Site
		CROSS APPLY (SELECT CAST(TRIM(value) AS INT) AS SiteID FROM STRING_SPLIT(d.Site,',')) sd
		CROSS APPLY (SELECT TOP 1 d.Domain FROM @tbSite s
						WHERE s.SiteID=sd.SiteID) s
		WHERE d.isDeleted=0 
		AND (@Countries='0' OR ISNULL(d.RestrictedCountries,'')=@Countries)	--Filter Countries: all/none Restricted Countries
		GROUP BY d.DomainID
	END

	SELECT d.DomainID, d.Domain, d.System, d.OfferType, d.site, d.BrandName
		, d.Status
		, d.RestrictedCountries
		, d.Remark
		, d.ExpiredDate
		, d.LastUpdateTime
	FROM DomainManagement d WITH (NOLOCK)
	INNER JOIN @tbDomains t ON t.DomainID=d.DomainID
	WHERE (@OfferType='' OR d.OfferType=@OfferType)
	AND (@Remark IS NULL OR d.Remark LIKE '%' + @Remark + '%')
	ORDER BY d.DomainID
END
GO