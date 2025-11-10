/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_GlobalStakeLevelGroup_Check] 
	-- Add the parameters for the stored procedure here
	 @InputData	VARCHAR(MAX)=''
	,@SettingStatus TINYINT = 0
	,@ErrCode	INT = 0				OUTPUT
	,@ErrMsg	NVARCHAR(4000)=''	OUTPUT
AS
/*
	Task: 3rd Products - Simplify RNG Games bet limit setting
	DB: DBACC/bodb02
	Original: 

	Revisions:
		- 20230918@Tacy: Initalize SP [RedmineID: #192624]
		- 20251110@Dave: Live Casino - Adjust-pt-comm-for-live-casino [RedmineID: #242260]
		
	Param's Explanation:
		* @InputData='<ROOT>
						<BetLimit 
							SportType="248" 
							CreditGroupID = "1"
							LicenseeGroupID = ""
							SiteID = "0"
							GameGroupID="1"
							CurMinBet="0.1" 
							CurMaxBet="10000" 
							CurRemark="Buybonus Feature x50"
							NewMinBet="0.1" 
							NewMaxBet="10001" 
							NewRemark=""
						/>
						<BetLimit 
							SportType="248" 
							CreditGroupID = "1"
							LicenseeGroupID = ""
							SiteID = "0"
							GameGroupID="2"
							CurMinBet="0.1" 
							CurMaxBet="2500" 
							CurRemark=""
							NewMinBet="0.1" 
							NewMaxBet="2501" 
							NewRemark="Buybonus Feature x50"
						/>
					</ROOT>'
*/
BEGIN
	SET NOCOUNT ON;
	
	IF ISNULL(@InputData,'')=''	RETURN

	DECLARE @xml XML, @ValueError VARCHAR(500)='', @RowError VARCHAR(200)=''

	DECLARE @NewGlobalTbl TABLE (
			 RowID				INT IDENTITY (1,1)
			, SportType			VARCHAR(5)
			, CreditGroupID		VARCHAR(5)
			, LicenseeGroupID	VARCHAR(5)
			, SiteID			VARCHAR(5)
			, GameGroupID		VARCHAR(5)
			, NewMinBet			VARCHAR(100)
			, NewMaxBet			VARCHAR(100)
			, NewRemark			VARCHAR(1000)
			, CurMinBet			VARCHAR(100)
			, CurMaxBet			VARCHAR(100)
			, CurRemark			VARCHAR(1000)
	)

	CREATE TABLE #NewInputDataTbl  (
			 RowID				INT 
			, SportType			SMALLINT
			, CurrencyGroupID	TINYINT
			, SiteID			INT DEFAULT (0)
			, GameGroupID		TINYINT
			, NewMinBet			MONEY
			, NewMaxBet			MONEY
			, NewRemark			VARCHAR(1000)
			, CurMinBet			MONEY
			, CurMaxBet			MONEY
			, CurRemark			VARCHAR(1000)
			, IsDeposit			BIT DEFAULT(0)
			, SportTypeRef		SMALLINT
			, Site				VARCHAR(50)
	)

	CREATE TABLE #Sports(SportType SMALLINT PRIMARY KEY, SportName NVARCHAR(50))
	CREATE TABLE #SettingDuplicate(SettingRows VARCHAR(50))
	CREATE TABLE #RowDuplicate(SettingRows VARCHAR(50))

	IF @InputData IS NULL OR @InputData=''
		RETURN
	
	SELECT @ErrCode=0, @ErrMsg=''
	
	--Parse XML data
	DECLARE @iDoc INT

	EXEC sp_xml_preparedocument @iDoc OUTPUT
		, @InputData

	INSERT INTO @NewGlobalTbl(	SportType, CreditGroupID, LicenseeGroupID, 
								GameGroupID, SiteID,
								NewMinBet, NewMaxBet, NewRemark,
								CurMinBet, CurMaxBet, CurRemark)
	SELECT	
			CASE WHEN ISNUMERIC(SportType)=0		THEN NULL ELSE SportType		END SportType,
			CASE WHEN ISNUMERIC(CreditGroupID)=0	THEN NULL ELSE CreditGroupID	END CreditGroupID,
			CASE WHEN ISNUMERIC(LicenseeGroupID)=0	THEN NULL ELSE LicenseeGroupID	END LicenseeGroupID,

			CASE WHEN ISNUMERIC(GameGroupID)=0		THEN NULL ELSE GameGroupID		END GameGroupID,
			CASE WHEN ISNUMERIC(SiteID)=0			THEN NULL ELSE SiteID			END SiteID,
			
			CASE WHEN ISNUMERIC(NewMinBet)=0		THEN NULL ELSE NewMinBet		END NewMinBet,
			CASE WHEN ISNUMERIC(NewMaxBet)=0		THEN NULL ELSE NewMaxBet		END NewMaxBet, 
			CASE WHEN ISNULL(NewRemark,'')=''		THEN NULL ELSE NewRemark		END NewRemark, 
			
			CASE WHEN ISNUMERIC(CurMinBet)=0		THEN NULL ELSE CurMinBet		END CurMinBet,
			CASE WHEN ISNUMERIC(CurMaxBet)=0		THEN NULL ELSE CurMaxBet		END CurMaxBet, 
			CASE WHEN ISNULL(CurRemark,'')=''		THEN NULL ELSE CurRemark		END CurRemark

	FROM OPENXML(@iDoc, '/ROOT/BetLimit', 1) WITH (
				  SportType			VARCHAR(5)
				, CreditGroupID		VARCHAR(5)
				, LicenseeGroupID	VARCHAR(5)
				, SiteID			VARCHAR(5)
				, GameGroupID		VARCHAR(5)
				, NewMinBet			VARCHAR(100)
				, NewMaxBet			VARCHAR(100)
				, NewRemark			VARCHAR(1000)
				, CurMinBet			VARCHAR(100)
				, CurMaxBet			VARCHAR(100)
				, CurRemark			VARCHAR(1000)
			)
	EXEC sp_xml_removedocument @iDoc

	-------------------------------------------------------------------------------------------------------------
	--Check: required field
	SELECT TOP (1)
			@ErrCode=CASE 
						WHEN ISNULL(SportType, '')=''		THEN 101
						WHEN ISNULL(GameGroupID, '')=''		THEN 102
						WHEN ISNULL(CreditGroupID, '')='' 
						 AND ISNULL(LicenseeGroupID, '')=''	THEN 103
						WHEN ISNULL(LicenseeGroupID, '')<>'' 
						 AND ISNULL(SiteID,'')=''			THEN 104
						WHEN ISNULL(NewMinBet, '')=''		THEN 105
						WHEN ISNULL(NewMaxBet, '')=''		THEN 106
						ELSE 100 
					END
			,@RowError=CAST(t.RowID AS VARCHAR(5))

			,@ValueError = CASE
							WHEN ISNULL(SportType, '')=''		THEN ': The Sport Type is required field.' 
							WHEN ISNULL(GameGroupID, '')=''		THEN ': The Game Group is required field.' 
							WHEN ISNULL(CreditGroupID, '')='' 
							 AND ISNULL(LicenseeGroupID, '')=''	THEN ': The Currency Group is required field.' 
							WHEN ISNULL(LicenseeGroupID, '')<>'' 
							 AND ISNULL(SiteID,'')=''			THEN ': The Site is required field.' 
							WHEN ISNULL(NewMinBet, '')=''		THEN ': The New Min Bet is required field.' 
							WHEN ISNULL(NewMaxBet, '')=''		THEN ': The New Max Bet is required field.' 
							ELSE '' 
						END 						  
	FROM @NewGlobalTbl t
	WHERE ISNULL(SportType, '')='' OR ISNULL(NewMinBet,'')='' OR ISNULL(NewMaxBet,'')=''
		OR (ISNULL(CreditGroupID, '')='' AND ISNULL(LicenseeGroupID, '')='')
		OR (ISNULL(LicenseeGroupID, '')<>'' AND ISNULL(SiteID,'')='')

	IF @ErrCode<>0 		
		GOTO SetErr
	
	-------------------------------------------------------------------------------------------------------------
	INSERT INTO #Sports	(SportType, SportName)	
	EXEC Acc_SporttypeSel @Mode=1

	DELETE FROM #Sports
	WHERE SportType BETWEEN 9913 AND 9915 --dummysport for PT setting

	CREATE TABLE #SportsNonSupported(
		  SportType		SMALLINT
		, IsDeposit		BIT
		, SiteID		INT
	)

	--Sports have setting by customer
	INSERT INTO #SportsNonSupported(SportType, IsDeposit)
	SELECT DISTINCT f.SportType, 1 AS IsDeposit
	FROM dbo.f_Dep_CustSetting_SportBetTypeSettingSelect(NULL, NULL, @SettingStatus) f
	WHERE f.SettingType IN (2, 7, 8, 10, 12)

	--#NewInputDataTbl
	INSERT INTO #NewInputDataTbl(RowID, SportType, CurrencyGroupID,
								 GameGroupID, SiteID,
								 NewMinBet, NewMaxBet, NewRemark,
								 CurMinBet, CurMaxBet, CurRemark,
								 IsDeposit)
	SELECT	RowID, SportType, CreditGroupID,
			GameGroupID, SiteID,
			NewMinBet, NewMaxBet, NewRemark,
			CurMinBet, CurMaxBet, CurRemark, 0 AS IsDeposit
	FROM @NewGlobalTbl nsl
	WHERE ISNULL(nsl.CreditGroupID,'')<>''
	UNION ALL
	SELECT	RowID, SportType, LicenseeGroupID,
			GameGroupID, SiteID,
			NewMinBet, NewMaxBet, NewRemark,
			CurMinBet, CurMaxBet, CurRemark, 1 AS IsDeposit
	FROM @NewGlobalTbl nsl
	WHERE ISNULL(nsl.LicenseeGroupID,'')<>''

	UPDATE TMP
	SET TMP.Site = si.Site
	FROM #NewInputDataTbl AS TMP
		INNER JOIN dbo.Site AS si
			ON TMP.SiteID =  si.siteid;
	
	UPDATE #NewInputDataTbl
	SET Site = 'All'
	WHERE SiteID = 0;

	--Update: SporttypeRef
	UPDATE t
	SET t.SportTypeRef=sm.SportTypeRefBetSetting
	FROM #NewInputDataTbl t
	CROSS APPLY (SELECT TOP 1 sm.SportTypeRefBetSetting
				 FROM f_CustSetting_SportBetTypeSettingMatrix (@SettingStatus) sm 
				 WHERE t.SportType=sm.SportType
				 AND t.IsDeposit=sm.isLicensee
				 AND sm.isActive=1 AND sm.isDeleted=0
				 AND (t.siteid = 0 OR sm.Site IN (t.site,'All'))) sm;

	
	--Sports have setting by customer
	WITH Tmp_Si AS(
		SELECT DISTINCT SiteID FROM #NewInputDataTbl WHERE IsDeposit = 0
	)
	INSERT INTO #SportsNonSupported(SportType, IsDeposit, SiteID)
	SELECT DISTINCT f.SportType, 0 AS IsDeposit, si.SiteID
	FROM Tmp_Si AS si
		CROSS APPLY dbo.f_CustSetting_ProductProfileSel(NULL,@SettingStatus,si.SiteID,0) f
	WHERE f.SettingType IN (2, 7, 16, 17, 23, 26);

	--------------------------------------------------------------------------------------------------------------------------------------
	SELECT TOP (1)
			@ErrCode=CASE 
						WHEN NewMinBet<=0									THEN 108
						WHEN NewMaxBet<=0									THEN 109
						WHEN NewMinBet > NewMaxBet							THEN 110
						WHEN CurMinBet > CurMaxBet							THEN 111
						WHEN CurMinBet IS NULL AND CurMaxBet IS NOT NULL	THEN 112
						WHEN CurMinBet IS NOT NULL AND CurMaxBet IS NULL	THEN 113
						WHEN CurMinBet IS NULL AND CurMaxBet IS NULL 
							AND CurRemark IS NOT NULL						THEN 126
						WHEN CurMinBet IS NOT NULL AND CurMaxBet IS NOT NULL THEN 
							CASE WHEN CurMinBet<=0							THEN 127
								 WHEN CurMaxBet<=0							THEN 128
							END
																			ELSE 107 
					END
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=CASE
							WHEN NewMinBet<=0 			THEN ': The Min Bet must be greater than 0.'
							WHEN NewMaxBet<=0			THEN ': The Max Bet must be greater than 0.'
							WHEN NewMinBet > NewMaxBet	THEN ': The New Min Bet must be less than or equal to the New Max Bet.'
							WHEN CurMinBet > CurMaxBet	THEN ': The Current Min Bet must be less than or equal to the Current Max Bet.'
							WHEN CurMinBet IS NULL AND CurMaxBet IS NOT NULL	THEN ': You input missing data with the product''s format. Please input data on Current Min Bet.'
							WHEN CurMinBet IS NOT NULL AND CurMaxBet IS NULL	THEN ': You input missing data with the product''s format. Please input data on Current Max Bet.'
							WHEN CurMinBet IS NULL AND CurMaxBet IS NULL 
								AND CurRemark IS NOT NULL						 THEN ': You input redundant data. Please remove data on Current Remark column.'
							WHEN CurMinBet IS NOT NULL AND CurMaxBet IS NOT NULL THEN 
								CASE WHEN CurMinBet<=0		THEN ': The Current Min Bet must be greater than 0.'
									 WHEN CurMaxBet<=0		THEN ': The Current Max Bet must be greater than 0.'
								END
							ELSE '' 
							END 						  
	FROM #NewInputDataTbl t
	WHERE NewMinBet<=0 OR NewMaxBet<=0
		OR (CurMinBet IS NULL AND CurMaxBet IS NOT NULL)
		OR (CurMaxBet IS NULL AND CurMinBet IS NOT NULL)
		OR (CurMinBet IS NULL AND CurMaxBet IS NULL AND CurRemark IS NOT NULL)
		OR NewMinBet > NewMaxBet 
		OR CurMinBet > CurMaxBet
		OR (CurMinBet IS NOT NULL AND CurMaxBet IS NOT NULL AND (CurMinBet<=0 OR CurMaxBet<=0))

	IF @ErrCode<>0
		GOTO SetErr

	--------------------------------------------------------------------------------------------------------------------------------------
	--Sporttype
	SELECT TOP(1)
			@ErrCode=114 
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=': The Sport Type ' + CAST (t.SportType AS VARCHAR(50)) + ' does not exist.'				
	FROM #NewInputDataTbl t
	LEFT JOIN #Sports s ON s.SportType=t.SportType 
	WHERE s.SportType IS NULL 

	IF @ErrCode=114			
		GOTO SetErr
		
	--Sports not support
	IF EXISTS (SELECT TOP 1 1 FROM #NewInputDataTbl t
				INNER JOIN #Sports s ON s.SportType=t.SportType
				LEFT JOIN #SportsNonSupported ref ON ref.SportType=t.SportTypeRef
												AND ref.IsDeposit=t.IsDeposit AND (ref.SiteID = t.siteID OR t.IsDeposit = 1)
				LEFT JOIN #SportsNonSupported sn ON sn.SportType=t.SportType
												AND sn.IsDeposit=t.IsDeposit AND (sn.SiteID = t.siteID OR t.IsDeposit = 1)
				WHERE ref.SportType IS NOT NULL OR sn.SportType IS NOT NULL)		
	BEGIN
		SELECT @ErrCode=119

		SELECT @ValueError=STUFF((SELECT DISTINCT ', ' + s.SportName 
								  FROM #NewInputDataTbl t
									INNER JOIN #Sports s ON s.SportType=t.SportType
									LEFT JOIN #SportsNonSupported ref ON ref.SportType=t.SportTypeRef
																	AND ref.IsDeposit=t.IsDeposit AND (ref.SiteID = t.siteID OR t.IsDeposit = 1)
									LEFT JOIN #SportsNonSupported sn ON sn.SportType=t.SportType
																	AND sn.IsDeposit=t.IsDeposit AND (sn.SiteID = t.siteID OR t.IsDeposit = 1)
								  WHERE ref.SportType IS NOT NULL OR sn.SportType IS NOT NULL
								  FOR XML PATH('')), 1, 1, '')

		SELECT @ValueError = 'This function does not support adding global bet limit settings for' + @ValueError + '.'

		GOTO SetErr
	END	

	--CurrencyGroupID
	SELECT TOP(1) 
			@ErrCode=115
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=CASE WHEN t.IsDeposit=0 AND ce.CreditGroupID IS NULL   THEN ': Credit Group ID ' 
							  WHEN t.IsDeposit=1 AND de.LicenseeGroupID IS NULL THEN ': Licensee Group ID ' 
						  END
						+ CAST (t.CurrencyGroupID AS VARCHAR(50)) 
						+ ' does not exist.'				
	FROM #NewInputDataTbl t
	OUTER APPLY (SELECT ce.CreditGroupID FROM Exchange ce WITH (NOLOCK)
				 WHERE ce.CreditGroupID=t.CurrencyGroupID
				 AND t.IsDeposit=0) ce
	OUTER APPLY (SELECT de.LicenseeGroupID FROM Exchange de WITH (NOLOCK)
				 WHERE de.LicenseeGroupID=t.CurrencyGroupID
				 AND t.IsDeposit=1) de
	WHERE (t.IsDeposit=0 AND ce.CreditGroupID IS NULL)
		OR (t.IsDeposit=1 AND de.LicenseeGroupID IS NULL)

	IF @ErrCode=115			
		GOTO SetErr

	--GameGroup
	;WITH cte_GameGroup AS (
		SELECT 1 AS GameGroupID, 'Slot Game' AS GameGroup
		UNION ALL
		SELECT 2 AS GameGroupID, 'Others' AS GameGroup
	)
	SELECT TOP(1) 
			@ErrCode=116
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=': Game Group ID ' 
						+ CAST (t.GameGroupID AS VARCHAR(50)) 
						+ ' does not exist.'				
	FROM #NewInputDataTbl t 
	LEFT JOIN cte_GameGroup g ON t.GameGroupID=g.GameGroupID
	WHERE g.GameGroupID IS NULL

	IF @ErrCode=116			
		GOTO SetErr

	--SiteID
	SELECT TOP(1) 
			@ErrCode=117
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=': Site ID ' 
						+ CAST (t.SiteID AS VARCHAR(50)) 
						+ ' does not exist.'				
	FROM #NewInputDataTbl t 
	LEFT JOIN Site s WITH (NOLOCK) ON s.siteid=t.SiteID
	WHERE t.SiteID<>0 AND t.IsDeposit=1
		AND s.siteid IS NULL

	IF @ErrCode=117			
		GOTO SetErr

	SELECT TOP(1) 
			@ErrCode=118
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=': Can not import Global Deposit Settings for specific Credit site.'
	FROM #NewInputDataTbl t 
	INNER JOIN Site s WITH (NOLOCK) ON s.siteid=t.SiteID
	WHERE t.SiteID<>0 AND t.IsDeposit=1		--Deposit setting lines
		AND s.siteid IS NOT NULL AND s.isDeposit=0	--credit site

	IF @ErrCode=118			
		GOTO SetErr

	--The same: new - current value
	SELECT TOP(1) 
			@ErrCode=122
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=': The New Min Bet, New Max Bet, New Remark are the same as The Current Min Bet, the Current Max Bet, the Current Remark. Please input another value for the New values again.'
	FROM #NewInputDataTbl t 
	WHERE t.CurMinBet=t.NewMinBet AND t.CurMaxBet=t.NewMaxBet AND ISNULL(t.CurRemark,'')=ISNULL(t.NewRemark,'')

	IF @ErrCode=122			
		GOTO SetErr

	--Already setting
	SELECT TOP(1) 
			@ErrCode=120
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=': This row had the current setting already. Please input data on the Current columns for updating purposes.'
	FROM #NewInputDataTbl t 
	WHERE (CurMinBet IS NULL OR CurMaxBet IS NULL)
		AND (
				(EXISTS (SELECT TOP 1 1 FROM ProductStakeLevelGroup psl WITH (NOLOCK)
						 WHERE t.SportType=psl.Sporttype
						 AND t.GameGroupID=psl.GameGroupID
						 AND t.CurrencyGroupID=psl.CreditGroupID
						 AND psl.isDeleted=0
						) 
					AND IsDeposit=0
				)
			OR
				(EXISTS (SELECT TOP 1 1 FROM Dep_ProductStakeLevelGroup psl WITH (NOLOCK)
						 WHERE t.SportType=psl.Sporttype
						 AND t.GameGroupID=psl.GameGroupID
						 AND t.CurrencyGroupID=psl.LicenseeGroupID
						 AND t.SiteID=psl.SiteID
						 AND psl.isDeleted=0
						) 
					AND IsDeposit=1
				)
			)

	IF @ErrCode=120			
		GOTO SetErr

	--does not have any existing bet limit with Current values
	SELECT TOP(1) 
			@ErrCode=121
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=': Sport Type ' + CAST (t.SportType AS VARCHAR(50))
						+ ' does not have any existing bet limit with Current Min Bet: ' + CAST (t.CurMinBet AS VARCHAR(50))
						+ ', Current Max Bet: ' + CAST (t.CurMaxBet AS VARCHAR(50))
	FROM #NewInputDataTbl t 
	WHERE t.CurMinBet IS NOT NULL AND t.CurMaxBet IS NOT NULL
		AND (
			(NOT EXISTS (SELECT TOP 1 1 FROM ProductStakeLevelGroup psl WITH (NOLOCK)
						WHERE t.SportType=psl.Sporttype
						AND t.GameGroupID=psl.GameGroupID
						AND t.CurrencyGroupID=psl.CreditGroupID
						AND t.CurMinBet=psl.MinBet
						AND t.CurMaxBet=psl.MaxBet
						AND psl.isDeleted=0
						) 
					AND IsDeposit=0)
			OR
			(NOT EXISTS (SELECT TOP 1 1 FROM Dep_ProductStakeLevelGroup psl WITH (NOLOCK)
						WHERE t.SportType=psl.Sporttype
						AND t.GameGroupID=psl.GameGroupID
						AND t.CurrencyGroupID=psl.LicenseeGroupID
						AND t.SiteID=psl.SiteID
						AND t.CurMinBet=psl.MinBet
						AND t.CurMaxBet=psl.MaxBet
						AND psl.isDeleted=0
						) 
					AND IsDeposit=1)
			)

	IF @ErrCode=121			
		GOTO SetErr

	--Upload more than 1 setting line with the same primary keys
	--Duplicate setting
	;WITH NewInputDataTbl AS (
		SELECT DISTINCT
			RowID, SportType
			, CurrencyGroupID, GameGroupID
			, SiteID, IsDeposit
		FROM #NewInputDataTbl t 
	)
	INSERT INTO #SettingDuplicate (SettingRows)
	SELECT STUFF((STUFF((SELECT ' - Row ' + CAST(RowID AS VARCHAR(5))
						 FROM NewInputDataTbl b
						 WHERE a.SportType=b.SportType
						 AND a.CurrencyGroupID=b.CurrencyGroupID
						 AND a.GameGroupID=b.GameGroupID 
						 AND a.IsDeposit = b.IsDeposit 
						 FOR XML PATH('')), 1, 1, '')),1,2,'') AS t
	FROM #NewInputDataTbl a
	WHERE a.IsDeposit=0
	GROUP BY SportType, CurrencyGroupID, GameGroupID, IsDeposit
	HAVING COUNT(1)>1
	UNION
	SELECT STUFF((STUFF((SELECT ' - Row ' + CAST(RowID AS VARCHAR(5))
						 FROM NewInputDataTbl b
						 WHERE a.SportType=b.SportType
						 AND a.CurrencyGroupID=b.CurrencyGroupID
						 AND a.GameGroupID=b.GameGroupID 
						 AND a.SiteID = b.SiteID 
						 AND a.IsDeposit = b.IsDeposit 
						 FOR XML PATH('')), 1, 1, '')),1,2,'') AS t
	FROM #NewInputDataTbl a
	WHERE a.IsDeposit=1
	GROUP BY SportType, CurrencyGroupID, GameGroupID, SiteID, IsDeposit
	HAVING COUNT(1)>1

	IF EXISTS (SELECT TOP 1 1 FROM #SettingDuplicate)			
	BEGIN
		SELECT @ErrCode=124
		SELECT @ValueError=STUFF((SELECT ', ' + SettingRows 
								FROM #SettingDuplicate t
								FOR XML PATH('')), 1, 1, '') + ': You can only upload 1 set of setting values. Please remove redundant data row(s).' 

		GOTO SetErr
	END	

	--RowDuplicate
	INSERT INTO #RowDuplicate (SettingRows)
	SELECT STUFF((STUFF((SELECT ' - Row ' + CAST(RowID AS VARCHAR(5))
						 FROM #NewInputDataTbl b
						 WHERE a.SportType=b.SportType
						 AND a.CurrencyGroupID=b.CurrencyGroupID
						 AND a.GameGroupID=b.GameGroupID 
						 AND a.IsDeposit = b.IsDeposit 
						 AND ISNULL(a.CurMinBet,0) = ISNULL(b.CurMinBet,0) AND ISNULL(a.CurMaxBet,0)=ISNULL(b.CurMaxBet,0) 
						 AND a.NewMaxBet = b.NewMaxBet AND a.NewMinBet = b.NewMinBet  
						 AND ISNULL(a.CurRemark,0) = ISNULL(b.NewRemark,0)  
						 FOR XML PATH('')), 1, 1, '')),1,2,'') AS t
	FROM #NewInputDataTbl a
	WHERE a.IsDeposit=0
	GROUP BY SportType, CurrencyGroupID, GameGroupID, IsDeposit
			, CurMinBet, CurMaxBet
			, NewMinBet, NewMaxBet
			, CurRemark, NewRemark
	HAVING COUNT(1)>1
	UNION
	SELECT STUFF((STUFF((SELECT ' - Row ' + CAST(RowID AS VARCHAR(5))
						 FROM #NewInputDataTbl b
						 WHERE a.SportType=b.SportType
						 AND a.CurrencyGroupID=b.CurrencyGroupID
						 AND a.GameGroupID=b.GameGroupID 
						 AND a.SiteID = b.SiteID 
						 AND a.IsDeposit = b.IsDeposit 
						 AND ISNULL(a.CurMinBet,0) = ISNULL(b.CurMinBet,0) AND ISNULL(a.CurMaxBet,0)=ISNULL(b.CurMaxBet,0) 
						 AND a.NewMaxBet = b.NewMaxBet AND a.NewMinBet = b.NewMinBet  
						 AND ISNULL(a.CurRemark,0) = ISNULL(b.NewRemark,0)  
						 FOR XML PATH('')), 1, 1, '')),1,2,'') AS t
	FROM #NewInputDataTbl a
	WHERE a.IsDeposit=1
	GROUP BY SportType, CurrencyGroupID, GameGroupID, SiteID, IsDeposit
			, CurMinBet, CurMaxBet
			, NewMinBet, NewMaxBet
			, CurRemark, NewRemark
	HAVING COUNT(1)>1
	
	IF EXISTS (SELECT TOP 1 1 FROM #RowDuplicate)			
	BEGIN
		SET @ErrCode=123
		SELECT @ValueError=STUFF((SELECT DISTINCT ', ' + SettingRows 
								FROM #RowDuplicate t
								FOR XML PATH('')), 1, 1, '') + ': These rows have duplicate data' 

		GOTO SetErr
	END	

	--EXISTED
	SELECT TOP(1) 
			@ErrCode=125
			,@RowError=CAST(KQ.RowID AS VARCHAR(5))
			,@ValueError=': This Bet Limit is already existed.'
	FROM 
	(	SELECT RowID 
		FROM #NewInputDataTbl a
		WHERE a.IsDeposit=0 
			AND (EXISTS (SELECT TOP 1 1 FROM ProductStakeLevelGroup psl WITH(NOLOCK) 
						 WHERE psl.Sporttype=a.SportType AND psl.GameGroupID=a.GameGroupID
							AND psl.CreditGroupID=a.CurrencyGroupID
							AND psl.isDeleted=0
							AND (a.NewMinBet=psl.MinBet AND a.NewMaxBet=psl.MaxBet
								 AND ISNULL(a.NewRemark,'')=ISNULL(psl.Remark,'')
								 )
						))
		UNION ALL
		SELECT RowID 
		FROM #NewInputDataTbl a
		WHERE a.IsDeposit=1 
			AND (EXISTS (SELECT TOP 1 1 FROM Dep_ProductStakeLevelGroup psl WITH(NOLOCK) 
						 WHERE psl.Sporttype=a.SportType AND psl.GameGroupID=a.GameGroupID
							AND psl.LicenseeGroupID=a.CurrencyGroupID 
							AND psl.SiteID=a.SiteID
							AND psl.isDeleted=0
							AND (a.NewMinBet=psl.MinBet AND a.NewMaxBet=psl.MaxBet
								 AND ISNULL(a.NewRemark,'')=ISNULL(psl.Remark,'')
								 )
						))
	) KQ
	
	IF @ErrCode=125			
		GOTO SetErr

	SetErr:
		IF @ErrCode<>0 
		BEGIN
			IF @RowError<>''
				SELECT @ErrMsg='Row ' + @RowError + @ValueError
			ELSE
				SELECT @ErrMsg=@ValueError

			RETURN
		END
END
GO