/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_GlobalSettingValidation]
	 @GlobalSetting VARCHAR(MAX) = ''
	 , @SportType SMALLINT = 1
AS
/*
	Created: Helen
	Date: 2017-09-18
	Task: global settings validation, import from excel file
	DB: DBCUST.CustDB

	Revisions:
		- 20190102@Malcolm: Separate setting and notification into Live/Non-Live and bettypes [Redmine : 125076]

	Parameter's explaination:
	Sample data for @GlobalSetting: 
		'<ROOT>
			<gs us="super01" isGH="x" maxTO="100" spt = "1" pfID = "1" rowID = "1"/>
			<gs us="super02" isGH="" maxTO="1" spt = "1" pfID = "2" rowID = "2"/>
		</ROOT>'
*/
BEGIN
	
	CREATE TABLE #GlobalSettingTbl (ID INT IDENTITY(1,1) PRIMARY KEY, Username NVARCHAR(50), IsGroupHeadline VARCHAR(50), MaxTurnover VARCHAR(50), SportType SMALLINT, ProfileID SMALLINT, rowID INT)
	
	CREATE TABLE #GlobalSettingTblError (ID INT, Username NVARCHAR(50), IsGroupHeadline VARCHAR(50), MaxTurnover VARCHAR(50), SportType SMALLINT, ProfileID SMALLINT, rowID INT, ErrorID TINYINT)		
	
	CREATE TABLE #ErrorList (ErrorID TINYINT, Reason VARCHAR(200))
	INSERT INTO #ErrorList (ErrorID,Reason)
	VALUES	(1, 'Invalid Username')
			, (2, 'The account is not a Headline')
			, (3, 'Invalid Headline value')
			, (4, 'Invalid Max Turnover')
		
	--Parse XML	
	DECLARE @iDoc INT

	EXEC sp_xml_preparedocument @iDoc OUTPUT, @GlobalSetting

	INSERT #GlobalSettingTbl (Username,IsGroupHeadline,MaxTurnover,SportType,ProfileID,rowID)
	SELECT us,ISNULL(isGH,'') AS IsGroupHeadline,maxTO,spt,pfID,rowID
	FROM OPENXML(@iDoc, '/ROOT/gs', 1) WITH (us NVARCHAR(50), isGH VARCHAR(50), maxTO VARCHAR(50), spt SMALLINT, pfID SMALLINT, rowID INT)

	EXEC sp_xml_removedocument @iDoc		
		
	INSERT INTO #GlobalSettingTblError (ID,Username,IsGroupHeadline,MaxTurnover,SportType,ProfileID,rowID,ErrorID)
	SELECT GS.ID, GS.Username,GS.IsGroupHeadline,GS.MaxTurnover,GS.SportType,GS.ProfileID, GS.rowID, 1
	FROM #GlobalSettingTbl GS WITH (NOLOCK)
		LEFT JOIN dbo.custInfo ci WITH (NOLOCK) ON gs.username = ci.username
	WHERE ci.custid IS NULL
	
	UNION ALL		
	
	SELECT GS.ID, GS.Username,GS.IsGroupHeadline,GS.MaxTurnover,GS.SportType,GS.ProfileID, GS.rowID, 2
	FROM #GlobalSettingTbl GS WITH (NOLOCK)
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON gs.username = ci.username
		LEFT JOIN dbo.CustGroupHeadline CA WITH (NOLOCK) ON CA.custid = ci.custid
	WHERE GS.IsGroupHeadline IN ('x','X') AND (CA.custid IS NULL)
	
	UNION ALL
	
	SELECT GS.ID, GS.Username,GS.IsGroupHeadline,GS.MaxTurnover,GS.SportType,GS.ProfileID, GS.rowID, 3
	FROM #GlobalSettingTbl GS WITH (NOLOCK)
	WHERE GS.IsGroupHeadline NOT IN ('x','X') AND GS.IsGroupHeadline <> ''
	
	UNION ALL
	
	SELECT GS.ID, GS.Username,GS.IsGroupHeadline,GS.MaxTurnover,GS.SportType,GS.ProfileID, GS.rowID, 4
	FROM #GlobalSettingTbl GS WITH (NOLOCK)
	WHERE (ISNUMERIC (GS.MaxTurnover) = 1 AND CONVERT(MONEY,GS.MaxTurnover) <= 0)
		 OR ISNUMERIC (GS.MaxTurnover) = 0
		
	-- VALID DATASET
	SELECT GS.Username
			, CASE 
					WHEN CA.custid IS NOT NULL THEN 'Headline'
					WHEN GS.IsGroupHeadline = '' AND CI.roleid = 4 THEN 'Super' 
					WHEN GS.IsGroupHeadline = '' AND CI.roleid = 3 THEN 'Master' 
					WHEN GS.IsGroupHeadline = '' AND CI.roleid = 2 THEN 'Agent' 
					
					ELSE ''
				END AS Level
			 , CASE WHEN CA.custid IS NOT NULL THEN 'RM' ELSE e.currency END AS Currency
			 , CONVERT(MONEY,GS.MaxTurnover) AS MaxTurnover
			 , GS.ProfileID
			 , PS.ProfileName
	FROM #GlobalSettingTbl GS WITH (NOLOCK)
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON gs.username = ci.username
		INNER JOIN dbo.exchange e WITH (NOLOCK) ON e.exchangeid = ci.currency
		LEFT JOIN dbo.custAccount CA WITH (NOLOCK) ON CA.custid = ci.custid AND GS.IsGroupHeadline in ('x','X')
		INNER JOIN TOControl_Profile PS WITH (NOLOCK) ON PS.ProfileID = GS.ProfileID
	WHERE NOT EXISTS (SELECT 1 FROM #GlobalSettingTblError GSE WITH (NOLOCK) WHERE GSE.rowID = GS.rowID)
	
	-- ERROR DATASET
	
	SELECT GS.rowID ,
		   GS.Username, 
		   CASE GS.ErrorID  WHEN 1 THEN 'Username'
							WHEN 2 THEN 'Headline'
							WHEN 3 THEN 'Headline'
							WHEN 4 THEN pf.ProfileName 
		   END AS Field,
		   CASE GS.ErrorID  WHEN 1 THEN GS.Username
							WHEN 2 THEN GS.IsGroupHeadline
							WHEN 3 THEN GS.IsGroupHeadline
							WHEN 4 THEN GS.MaxTurnover 
		   END AS 'Value',
		   ErrorRef.Reason AS Reason	  
	FROM #GlobalSettingTblError GS WITH (NOLOCK)
		INNER JOIN #ErrorList ErrorRef WITH(NOLOCK) ON GS.ErrorID = ErrorRef.ErrorID
		INNER JOIN TOControl_Profile pf WITH (NOLOCK) ON pf.ProfileID = GS.ProfileID

	
	DROP TABLE #ErrorList
	DROP TABLE #GlobalSettingTbl
	DROP TABLE #GlobalSettingTblError
		
END
GO

