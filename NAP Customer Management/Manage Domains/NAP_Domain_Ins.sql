/*<info serverAlias="DBGLOB-GlobCustDB" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROC [dbo].[NAP_Domain_Ins]
	 @DomainList	NVARCHAR(MAX)	OUTPUT
	,@UserID		INT
	,@IP			VARCHAR(50)	= ''
	,@ErrCode		INT=0			 OUTPUT
	,@ErrMsg		VARCHAR(2000)='' OUTPUT
	,@DomainListOutput	NVARCHAR(MAX)	OUTPUT
AS
/*
	Created: 20231013@Tacy
	Task: Insert/Update domain
	DB: DBGLOB-GlobCustDB
	
	Revisions:
		- 20231013@Tacy: NAP CM - Manage Domain [RedmineID: #194024]
		- 20250120@Tacy: Move to GlobCustDB [RedmineID: #216870]

	Param's Explanation:
		@DomainList:
			**Add new:
				<DomainList>
						<Domain id="" d="alpha01.com" ss="Agency" s="1045,1046,1047,1048" stt="2" ed="2023-10-17 23:59:59" c="VN,AF,AO" r="" b="B"/>
						<Domain id="" d="alpha02.com" ss="Agency" s="1045,1046,1047,1048" stt="2" ed="2023-11-17 23:59:59" c=""			r="" b="V"/>
				</DomainList>

			**Update:
				<DomainList>
						<Domain id="1" d="alpha01.com" ss="Agency" s="1045,1046,1047,1048" stt="2" ed="2023-10-17 23:59:59" c="VN,AF,AO" r="" b="B"/>
						<Domain id="2" d="alpha02.com" ss="Agency" s="1045,1046,1047,1048" stt="2" ed="2023-11-17 23:59:59" c=""		 r="" b="V"/>
				</DomainList>

			@id ~ DomainID
			@d  ~ DomainName
			@ss ~ System: {'Agency','Member Site'}
			@s  ~ Site
			@stt ~ Status: {0 ~ Unavailable; 1 ~ Available; 2 ~ In-stock; 3 ~ Active}
			@ed	~ ExpiredDate
			@c  ~ Countries
			@r  ~ Remark
			@b	~ BrandName: {'B'; 'V'}
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @logSpData NVARCHAR(MAX)

	SET @StartRun = GETDATE()	

	EXEC NAP_Domain_Check @DomainList=@DomainList	
						 ,@IsUpdate=0
						 ,@ErrCode=@ErrCode	OUTPUT
						 ,@ErrMsg=@ErrMsg OUTPUT

	IF @ErrCode<>0	RETURN

	CREATE TABLE #tbDomains (
			 Domain				VARCHAR(50)
			,System				VARCHAR(20)
			,Site				VARCHAR(500)
			,Status				TINYINT
			,ExpiredDate		DATETIME
			,RestrictedCountries VARCHAR(4000)
			,Remark				NVARCHAR(2000)
			,BrandName			VARCHAR(10)
	)

	DECLARE @tbAnnoucementDomain TABLE (Domain VARCHAR(50),Site	VARCHAR(200))

	--Parse XML data
	DECLARE @iDoc INT

	EXEC sp_xml_preparedocument @iDoc OUTPUT
		, @DomainList

	INSERT INTO #tbDomains(Domain, System, Site, Status, ExpiredDate, RestrictedCountries, Remark, BrandName)
	SELECT	d	AS Domain, 
			ss	AS [System], 
			s	AS [Site], 
			stt AS [Status],
			CASE WHEN LEN(ed)=0			THEN NULL ELSE ed	END ExpiredDate, 
			CASE WHEN LEN(c)=0			THEN NULL ELSE c	END RestrictedCountries,
			CASE WHEN LEN(r)=0			THEN NULL ELSE r	END Remark, 
			CASE WHEN LEN(b)=0			THEN NULL ELSE b	END BrandName 
	FROM OPENXML(@iDoc, '/DomainList/Domain', 1) WITH (
				 id		SMALLINT
				,d		VARCHAR(50)
				,ss		VARCHAR(20)
				,s		VARCHAR(500)
				,stt	TINYINT
				,ed		VARCHAR(50)
				,c		VARCHAR(4000)
				,r		NVARCHAR(2000)
				,b		VARCHAR(10)
			)
	EXEC sp_xml_removedocument @iDoc

	BEGIN TRY
		INSERT INTO DomainManagement(Domain, System, Site, BrandName, Status, ExpiredDate, RestrictedCountries, Remark)
		SELECT Domain, System, Site, BrandName, Status, ExpiredDate, RestrictedCountries, Remark
		FROM #tbDomains t 
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE();		
		RETURN
	END CATCH

	--Writelog
	SELECT @EndRun	= GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

	DECLARE @NewLog VARCHAR(MAX)
	SET @NewLog = '<DomainList IP="'+ COALESCE(CAST(@IP AS VARCHAR(15)),'')+'" >'
	
	SELECT @logSpData = REPLACE(REPLACE(@DomainList, '<DomainList>', @NewLog),' id="" ',SPACE(1))

	EXEC  Acc_WriteLog_UserLog_RunSP_Wrapper
				@UserID = @UserID,
				@ActionID = 31773,
				@TrackingValue = @LogSPData,
				@duration = @Duration

	--Domains is Active
	;WITH tmp AS (
		SELECT Domain, s.site
		FROM #tbDomains d
		CROSS APPLY (SELECT CAST(TRIM(value) AS INT) SiteID FROM STRING_SPLIT(D.Site,',')) t
		INNER JOIN Site s WITH (NOLOCK) ON s.siteid=t.SiteID
		WHERE Status=3
	)
	INSERT INTO @tbAnnoucementDomain (Domain, Site)
	SELECT Domain, 
		STUFF ((SELECT ',' + site
                FROM tmp t1
				WHERE t1.Domain=t.Domain
                FOR XML PATH('')),1,1,'') as site
	FROM tmp t
	GROUP BY Domain

	--Gen XML to add Announcement
	SELECT @DomainListOutput = CONVERT(VARCHAR(MAX),
									(SELECT d.Domain AS 'd'
										, d.Site	 AS 's'
									 FROM @tbAnnoucementDomain d
									 FOR XML RAW ('Domain'), ROOT ('DomainList'))
							)
END
GO