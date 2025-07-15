/*<info serverAlias="DBGLOB-GlobCustDB" executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROC [dbo].[NAP_Domain_Check]
	 @DomainList	NVARCHAR(MAX)		
	,@CashSite 		VARCHAR(MAX) = ''
	,@IsUpdate		BIT=0
	,@Action		VARCHAR(20) = ''
	,@ErrCode		INT=0			 OUTPUT
	,@ErrMsg		VARCHAR(2000)='' OUTPUT
AS
/*
	Created: 20231013@Tacy
	Task: Validation Domains
	DB: DBGLOB-GlobCustDB
	
	Revisions:
		- 20231013@Tacy: NAP CM - Manage Domain [RedmineID: #194024]
		- 20250120@Tacy: Move to GlobCustDB [RedmineID: #216870]
		- 20250624@Johnson: offer Agency Cash Service [RedmineID: #231219]
		- 20250709@Egan: Add delete validation support and more rules on cash service [RedmineID: #231219]
	Param's Explanation:
		@DomainList:
			**Add new:
				<DomainList>
						<Domain id="" d="alpha01.com" ss="Agency" cs="1" s="1045,1046,1047,1048" stt="2" ed="2023-10-17 23:59:59" c="VN,AF,AO" r="" b="B"/>
						<Domain id="" d="alpha02.com" ss="Agency" cs="0" s="1045,1046,1047,1048" stt="2" ed="2023-11-17 23:59:59" c=""			r="" b="V"/>
				</DomainList>

			**Update:
				<DomainList>
						<Domain id="1" d="alpha01.com" ss="Agency" cs="1" s="1045,1046,1047,1048" stt="2" ed="2023-10-17 23:59:59" c="VN,AF,AO" r="" b="B"/>
						<Domain id="2" d="alpha02.com" ss="Agency" cs="0" s="1045,1046,1047,1048" stt="2" ed="2023-11-17 23:59:59" c=""		 r="" b="V"/>
				</DomainList>

			**Delete (simple format):
				<DomainList>
						<Domain id="1" d="alpha01.com" />
						<Domain id="2" d="alpha02.com" />
				</DomainList>

			@id ~ DomainID
			@d  ~ DomainName
			@ss ~ System: {'Agency','Member Site'}
			@cs ~ CashService: {0 ~ No; 1 ~ Yes}
			@s  ~ Site
			@stt ~ Status: {0 ~ Unavailable; 1 ~ Available; 2 ~ In-stock; 3 ~ Active}
			@ed	~ ExpiredDate
			@c  ~ Countries
			@r  ~ Remark
			@b	~ BrandName: {'B'; 'V'}		
			@CashSite ~ list cash site('best-odds,733333,...')
			@Action ~ Action type: {'Delete'} for delete operations
*/
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #tbDomains (
			 DomainID			SMALLINT
			,Domain				VARCHAR(50)
			,System				VARCHAR(20)
			,CashService		BIT
			,Site				VARCHAR(500)
			,Status				TINYINT
			,ExpiredDate		DATETIME
			,RestrictedCountries VARCHAR(4000)
			,Remark				NVARCHAR(2000)
			,BrandName			VARCHAR(10)
	)

	DECLARE @tbSiteMarket TABLE (SiteID INT, Site VARCHAR(50), SiteLabel VARCHAR(50), MarketCode VARCHAR(30))

	INSERT INTO @tbSiteMarket (SiteID, Site, SiteLabel, MarketCode)
	EXEC dbo.NAP_Domain_SiteMarket

	--Parse XML data
	DECLARE @iDoc INT

	EXEC sp_xml_preparedocument @iDoc OUTPUT
		, @DomainList

	-- For delete operations, we need to get complete domain data from database
	IF @Action = 'Delete'
	BEGIN
		INSERT INTO #tbDomains(DomainID,Domain, System, CashService, Site, Status, ExpiredDate, RestrictedCountries, Remark, BrandName)
		SELECT	d.DomainID,
				d.Domain,
				d.System,
				d.OfferType,
				d.Site,
				d.Status,
				d.ExpiredDate,
				d.RestrictedCountries,
				d.Remark,
				d.BrandName
		FROM DomainManagement d WITH (NOLOCK)
		INNER JOIN (
			SELECT t.s.value('@id','SMALLINT') AS DomainID
			FROM (SELECT CAST(@DomainList AS XML)) AS x(xml)
			CROSS APPLY x.xml.nodes('DomainList/Domain') t(s)
		) input ON d.DomainID = input.DomainID AND d.isDeleted = 0
	END
	ELSE
	BEGIN
		INSERT INTO #tbDomains(DomainID,Domain, System, CashService, Site, Status, ExpiredDate, RestrictedCountries, Remark, BrandName)
		SELECT	CASE WHEN ISNUMERIC(id)=0	THEN NULL ELSE id	END DomainID,
				CASE WHEN LEN(d)=0			THEN NULL ELSE d	END Domain, 
				CASE WHEN LEN(ss)=0			THEN NULL ELSE ss	END [System], 
				CASE WHEN LEN(cs)=0			THEN NULL ELSE cs	END [CashService], 
				CASE WHEN LEN(s)=0			THEN NULL ELSE s	END [Site], 
				CASE WHEN LEN(stt)=0		THEN NULL ELSE stt	END [Status], 
				CASE WHEN LEN(ed)=0			THEN NULL ELSE ed	END ExpiredDate, 
				CASE WHEN LEN(c)=0			THEN NULL ELSE c	END RestrictedCountries,
				CASE WHEN LEN(r)=0			THEN NULL ELSE r	END Remark, 
				CASE WHEN LEN(b)=0			THEN NULL ELSE b	END BrandName 
		FROM OPENXML(@iDoc, '/DomainList/Domain', 1) WITH (
					 id		VARCHAR(10)
					,d		VARCHAR(50)
					,ss		VARCHAR(20)
					,cs 	VARCHAR(10)
					,s		VARCHAR(500)
					,stt	VARCHAR(10)
					,ed		VARCHAR(50)
					,c		VARCHAR(4000)
					,r		NVARCHAR(2000)
					,b		VARCHAR(10)
				)
	END
	
	EXEC sp_xml_removedocument @iDoc
	
	-- For delete operations, skip required field checks since we get data from DB
	IF @Action <> 'Delete'
	BEGIN
		--check: required field
		SELECT TOP (1)
				@ErrCode=CASE WHEN Domain IS NULL	THEN 101
							  WHEN System IS NULL	THEN 102
							  WHEN Site IS NULL		THEN 103
							  WHEN Status IS NULL	THEN 104
							  WHEN CashService IS NULL	THEN 111
							  ELSE 100
					END,
				@ErrMsg=CASE WHEN Domain IS NULL	THEN 'The Domain is required field.'
							 WHEN System IS NULL	THEN 'The System is required field.'
							 WHEN Site IS NULL		THEN 'The Site is required field.'
							 WHEN Status IS NULL	THEN 'The Status is required field.'
							 WHEN CashService IS NULL THEN 'The Offer Cash Service is required field.'
							 ELSE ''
					END
		FROM #tbDomains
		WHERE Domain IS NULL OR System IS NULL
			OR Site IS NULL OR Status IS NULL
			OR CashService IS NULL
			OR (DomainID IS NULL AND @IsUpdate=1)

		IF @ErrCode<>0	RETURN

		--Max: 50 domains
		IF EXISTS (SELECT TOP 1 1 FROM #tbDomains HAVING COUNT(1)>50)
		BEGIN
			SELECT @ErrCode=105
				,@ErrMsg='The maximum number of domains has been exceeded.'
			RETURN
		END

		--Check: existed domain when add new/update:
		SELECT TOP 1 
				@ErrCode=106
				,@ErrMsg='The ' + t.Domain + ' is existed.'
		FROM #tbDomains t
		INNER JOIN DomainManagement d ON d.Domain=t.Domain
		WHERE d.isDeleted=0 
		AND 1 = CASE WHEN @IsUpdate=0			 THEN 1
					 WHEN t.DomainID<>d.DomainID THEN 1
					 ELSE 0
				END

		IF @ErrCode=106	RETURN

		--Check: Site
		SELECT TOP 1 
				 @ErrCode=107
				,@ErrMsg='The ' + sm.Site + ' is not exist.'
		FROM #tbDomains d
		CROSS APPLY (SELECT CAST(TRIM(t.value) AS INT) SiteID FROM string_split(d.Site,',') t) t
		LEFT JOIN @tbSiteMarket sm ON t.SiteID=sm.SiteID
		WHERE sm.SiteID IS NULL

		IF @ErrCode=107	RETURN

		--Check: Cash service domains can only be added for sites in CashSite list
		IF @CashSite <> ''
		BEGIN
			SELECT TOP 1 
				@ErrCode=117
				,@ErrMsg='You''re unable to enable Offer Cash right now because no sites currently support the cash service.'
			FROM #tbDomains d
			WHERE d.CashService = 1 
				AND NOT EXISTS (
					-- Check if there is no site offer cash
					SELECT TOP 1 1
					FROM #tbDomains d2
					CROSS APPLY (SELECT CAST(TRIM(t.value) AS INT) SiteID FROM string_split(d2.Site,',') t) t
					INNER JOIN @tbSiteMarket sm ON t.SiteID=sm.SiteID
					WHERE (d2.DomainID = d.DomainID OR (d2.DomainID IS NULL AND d.DomainID IS NULL AND d2.Domain = d.Domain))
						AND sm.site IN (SELECT value FROM string_split(@CashSite,','))
				)

			IF @ErrCode=117	RETURN
		END

		--Check duplicate domain:
		IF EXISTS (SELECT TOP 1 1 FROM #tbDomains GROUP BY Domain HAVING COUNT(1)>1)
		BEGIN
			SELECT @ErrCode=108
				, @ErrMsg= 'Duplicated domain(s):' + 
						(SELECT STUFF((SELECT ', ' + Domain
										FROM #tbDomains
										GROUP BY Domain
										HAVING COUNT(1)>1
										FOR XML PATH(''))
										,1,1,'')
							)
			RETURN
		END

		--This domain is not available
		SELECT TOP 1 
				@ErrCode=109
				,@ErrMsg='The ' + t.Domain + ' is not available.'
		FROM #tbDomains t
		LEFT JOIN DomainManagement d ON d.DomainID=t.DomainID
		WHERE d.isDeleted=0 AND @IsUpdate=1 AND d.DomainID IS NULL

		IF @ErrCode=109	RETURN

		--Update domain name when update multiple
		SELECT TOP 1 
				@ErrCode=110
				,@ErrMsg='Can be update the domain name.'
		FROM #tbDomains t
		INNER JOIN DomainManagement d ON d.DomainID=t.DomainID
		WHERE d.isDeleted=0 AND @IsUpdate=1 AND d.Domain <> t.Domain
		HAVING COUNT(1)>1

		IF @ErrCode=110	RETURN
	END
	
	-- For delete operations, check if domains exist and are not already deleted
	IF @Action = 'Delete'
	BEGIN
		-- Check if domains exist and are not deleted
		SELECT TOP 1 
				@ErrCode=109
				,@ErrMsg='The ' + t.Domain + ' is not available.'
		FROM #tbDomains t
		LEFT JOIN DomainManagement d ON d.DomainID=t.DomainID
		WHERE d.isDeleted=0 AND d.DomainID IS NULL

		IF @ErrCode=109	RETURN
	END
	
	--Check if more than 2 domains with Cash Service enabled per site
	-- Only perform this check if there are cash service domains in the new domain list
	-- Skip this check for delete operations since we're removing domains, not adding them
	IF EXISTS (SELECT TOP 1 1 FROM #tbDomains WHERE CashService = 1 AND Status = 3) AND @Action <> 'Delete'
	BEGIN
		;WITH SitesInNewDomains AS (
			-- Get all sites from the new domain list
			SELECT DISTINCT s.SiteID
			FROM #tbDomains t
			CROSS APPLY (SELECT CAST(TRIM(t.value) AS INT) SiteID FROM string_split(t.Site,',') t) s
			WHERE s.SiteID IN (SELECT sm.SiteID FROM @tbSiteMarket sm WHERE sm.site IN (SELECT value FROM string_split(@CashSite,',')))
		),
		CashServiceDomains AS (
			-- Get existing active cash service domains from DomainManagement for sites in new domain list
			-- Exclude domains that are being updated (to avoid double counting)
			SELECT s.SiteID, d.DomainID
			FROM DomainManagement d WITH(NOLOCK)
			CROSS APPLY (SELECT CAST(TRIM(t.value) AS INT) SiteID FROM string_split(d.Site,',') t) s
			INNER JOIN SitesInNewDomains sid ON s.SiteID = sid.SiteID
			WHERE d.isDeleted = 0 
				AND d.Status = 3 
				AND d.OfferType = 1
				AND d.DomainID NOT IN (SELECT DomainID FROM #tbDomains WHERE DomainID IS NOT NULL)
			UNION ALL
			-- Get new/updated cash service domains from input
			SELECT s.SiteID, t.DomainID
			FROM #tbDomains t
			CROSS APPLY (SELECT CAST(TRIM(t.value) AS INT) SiteID FROM string_split(t.Site,',') t) s
			WHERE t.CashService = 1 AND t.Status = 3
		)
		SELECT TOP 1 
				@ErrCode=115
				,@ErrMsg='Cannot proceed: Site' + ISNULL(sm.Site,'') + ' already has the maximum of 2 domains with ''Offer Cash Service'' enabled.'
		FROM CashServiceDomains csd
		INNER JOIN @tbSiteMarket sm ON csd.SiteID=sm.SiteID
		GROUP BY sm.Site, sm.SiteID
		HAVING COUNT(1) > 2

		IF @ErrCode=115	RETURN
	END
	
	--check for cash service
	IF @IsUpdate=1 
	BEGIN
		--Check if update status to in-active for domain cash service	
		SELECT TOP 1 
			@ErrCode=111
			,@ErrMsg='Cannot proceed - at least one active Cash Service domain must be maintained for site:' + ISNULL(sm.Site,'')
		FROM #tbDomains t
		INNER JOIN DomainManagement d ON d.DomainID=t.DomainID
		CROSS APPLY (SELECT CAST(TRIM(t.value) AS INT) SiteID FROM string_split(d.Site,',') t) s
		INNER JOIN @tbSiteMarket sm ON s.SiteID=sm.SiteID
		WHERE d.isDeleted=0 AND @IsUpdate=1 
			AND (t.Status <> 3 AND d.Status = 3
				AND t.CashService= 1 AND d.OfferType = 1
				AND NOT EXISTS (SELECT TOP 1 1 FROM DomainManagement d2 WITH(NOLOCK)
									CROSS APPLY (SELECT CAST(TRIM(t.value) AS INT) SiteID FROM string_split(d2.Site,',') t) s2
								WHERE s.SiteID = s2.SiteID
									AND d2.DomainID <> d.DomainID
									AND d2.isDeleted=0 AND d2.Status = 3
									AND d2.OfferType = 1
								)
			)		
		AND sm.site IN (SELECT value FROM string_split(@CashSite,','))	
		
		IF @ErrCode=111	RETURN

		--Check if update system from Agency to Member
		SELECT TOP 1 
			@ErrCode=112
			,@ErrMsg='Cannot proceed - at least one active Cash Service domain must be maintained for site:' + ISNULL(sm.Site,'')
		FROM #tbDomains t
		INNER JOIN DomainManagement d ON d.DomainID=t.DomainID
		CROSS APPLY (SELECT CAST(TRIM(t.value) AS INT) SiteID FROM string_split(d.Site,',') t) s
		INNER JOIN @tbSiteMarket sm ON s.SiteID=sm.SiteID
		WHERE d.isDeleted=0 AND @IsUpdate=1 
			AND t.Status = 3 AND t.system = 'Agency'
			AND d.OfferType = 1 AND d.Status = 3 AND d.System = 'Member'
			AND NOT EXISTS (SELECT TOP 1 1 FROM DomainManagement d2 WITH(NOLOCK)
								CROSS APPLY (SELECT CAST(TRIM(t.value) AS INT) SiteID FROM string_split(d2.Site,',') t) s2
							WHERE s.SiteID = s2.SiteID
								AND d2.DomainID <> d.DomainID
								AND d2.isDeleted=0 AND d2.Status = 3
								AND d2.OfferType = 1
							)		
			AND sm.site IN (SELECT value FROM string_split(@CashSite,','))	
		
		IF @ErrCode=112	RETURN

		--check if update domain cash service to non-cash service
		SELECT TOP 1 
			@ErrCode=113
			,@ErrMsg='Cannot proceed - at least one active Cash Service domain must be maintained for site:' + ISNULL(sm.Site,'')
		FROM #tbDomains t
		INNER JOIN DomainManagement d ON d.DomainID=t.DomainID
		CROSS APPLY (SELECT CAST(TRIM(t.value) AS INT) SiteID FROM string_split(d.Site,',') t) s
		INNER JOIN @tbSiteMarket sm ON s.SiteID=sm.SiteID
		WHERE d.isDeleted=0 AND @IsUpdate=1 
			AND t.CashService= 0 AND t.Status = 3 
			AND d.OfferType = 1 AND d.Status = 3
			AND NOT EXISTS (SELECT TOP 1 1 FROM DomainManagement d2 WITH(NOLOCK)
								CROSS APPLY (SELECT CAST(TRIM(t.value) AS INT) SiteID FROM string_split(d2.Site,',') t) s2
							WHERE s.SiteID = s2.SiteID
								AND d2.DomainID <> d.DomainID
								AND d2.isDeleted=0 AND d2.Status = 3
								AND d2.OfferType = 1
							)		
			AND sm.site IN (SELECT value FROM string_split(@CashSite,','))	
		
		IF @ErrCode=113	RETURN

		--Check if remove site info for domain cash service
		IF EXISTS (SELECT top 1 DomainID FROM #tbDomains WHERE CashService=1 AND Status=3)
		BEGIN
			CREATE TABLE #tmpCashSite(
				SiteID INT,
				DomainID SMALLINT
			)
			
			INSERT INTO #tmpCashSite(SiteID, DomainID)
			SELECT s1.SiteID, d.DomainID			
			FROM DomainManagement d WITH(NOLOCK)
			CROSS APPLY (SELECT CAST(TRIM(t1.value) AS INT) SiteID FROM string_split(d.Site,',') t1) s1	
			WHERE d.isDeleted=0 
				AND d.Status = 3
				AND d.OfferType = 1	
				--AND d.DomainID IN (SELECT DomainID FROM #tbDomains WHERE CashService=1 AND Status=3)

			--site domain update
			;WITH tmpCashSiteDomain AS (
			SELECT SiteID, DomainID
			FROM #tmpCashSite d
			WHERE d.DomainID IN (SELECT DomainID FROM #tbDomains WHERE CashService=1 AND Status=3)
			),
			--site domain remove
			TmpSiteRemove AS(
			SELECT SiteID, DomainID
			FROM tmpCashSiteDomain s1
			WHERE NOT EXISTS (SELECT DomainID FROM #tbDomains t
									CROSS APPLY (SELECT CAST(TRIM(t2.value) AS INT) SiteID FROM string_split(t.Site,',') t2) s2
								WHERE t.DomainID=s1.DomainID
									AND CashService=1 AND Status=3 							
									AND s1.SiteID = s2.SiteID							
								)
			)
			--get site remove all domains
			SELECT TOP 1
				@ErrCode=114
				,@ErrMsg='Cannot proceed - at least one active Cash Service domain must be maintained for site:' + ISNULL(sm.Site,'')
			FROM TmpSiteRemove t2
				INNER JOIN @tbSiteMarket sm ON t2.SiteID=sm.SiteID		
			WHERE sm.site IN (SELECT value FROM string_split(@CashSite,','))	
			GROUP BY sm.Site,t2.SiteID
			HAVING NOT EXISTS (
					--get site not remove yet
					SELECT 1
					FROM #tmpCashSite t1
					WHERE t1.siteid = t2.siteid
					AND NOT EXISTS (
						SELECT 1
						FROM TmpSiteRemove t2b
						WHERE t2b.siteid = t1.siteid AND t2b.domainID = t1.domainID
					)
				)
		END		

		IF @ErrCode=114	RETURN
	END
	
	-- Check for delete operations - ensure we don't delete the last active cash service domain for any site
	IF @Action = 'Delete'
	BEGIN
		-- Check if deleting active cash service domains would leave any site without an active cash service domain
		SELECT TOP 1 
			@ErrCode=116
			,@ErrMsg='Cannot proceed - at least one active Cash Service domain must be maintained for site:' + ISNULL(affectedSites.Site,'')
		FROM (
			-- Get all sites that will be affected by the deletion
			SELECT DISTINCT s.SiteID, sm.Site
			FROM #tbDomains t
			CROSS APPLY (SELECT CAST(TRIM(s.value) AS INT) SiteID FROM string_split(t.Site,',') s) s
			INNER JOIN @tbSiteMarket sm ON s.SiteID=sm.SiteID
			WHERE t.CashService = 1 AND t.Status = 3
				AND sm.site IN (SELECT value FROM string_split(@CashSite,','))
		) affectedSites
		WHERE NOT EXISTS (
			-- Check if there will be at least one active cash service domain remaining for this site
			SELECT TOP 1 1 
			FROM DomainManagement d2 WITH(NOLOCK)
			CROSS APPLY (SELECT CAST(TRIM(s2.value) AS INT) SiteID FROM string_split(d2.Site,',') s2) s2
			WHERE s2.SiteID = affectedSites.SiteID
				AND d2.DomainID NOT IN (SELECT DomainID FROM #tbDomains WHERE DomainID IS NOT NULL)
				AND d2.isDeleted = 0 
				AND d2.Status = 3 
				AND d2.OfferType = 1
		)
		
		IF @ErrCode=116	RETURN
	END
END
GO