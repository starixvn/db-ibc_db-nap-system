/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_GlobalStakeGroup_Check] 
	-- Add the parameters for the stored procedure here
	 @InputData	VARCHAR(MAX)=''
	,@SettingStatus TINYINT = 0
	,@UserID	INT
	,@IP		VARCHAR(50)=''
	--,@NotiCode	INT=0			OUTPUT
	--,@NotiMsg	NVARCHAR(4000)=''	OUTPUT
	,@ErrCode	INT = 0				OUTPUT
	,@ErrMsg	NVARCHAR(4000)=''	OUTPUT
AS
/*
	Task: 3rd Products - Simplify RNG Games bet limit setting
	DB: DBACC/bodb02
	Original: 

	Revisions:
		- 20230918@Tacy: Initalize SP [RedmineID: #192624]
		
	Param's Explanation:
		* @InputData = <ROOT>
						<Setting 
							SportType="248" 
							CreditGroupID = "RM,HKK"
							LicenseeGroupID = ""
							Site = ""
							GameGroupID="1"
							CurMinBet="0.01" 
							CurMaxBet="400" 
							CurRemark="Buybonus Feature x50"
							NewMinBet="0.01" 
							NewMaxBet="400" 
							NewRemark=""
						/>
						<Setting 
							SportType="248" 
							CreditGroupID = "RM,HKK"
							LicenseeGroupID = ""
							Site = ""
							GameGroupID="2"
							CurMinBet="0.01" 
							CurMaxBet="1000" 
							CurRemark=""
							NewMinBet="0.01" 
							NewMaxBet="1000" 
							NewRemark="Buybonus Feature x50"
						/>
					</ROOT>
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
			, IsCredit			BIT DEFAULT(0)
			, ProductID			TINYINT
	)

	CREATE TABLE #Sports(SportType SMALLINT PRIMARY KEY, SportName NVARCHAR(50))
	CREATE TABLE #SettingDuplicate(SettingRows VARCHAR(50))
	CREATE TABLE #RowDuplicate(RowIDF INT, RowIDT INT)

	IF @InputData IS NULL OR @InputData=''
		RETURN
	
	SELECT @ErrCode=0, @ErrMsg=''--, @NotiCode=0, @NotiMsg=''
	
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

	CREATE TABLE #SportsNonOffered(
		  SportType		SMALLINT
		, BetType		SMALLINT
		, ProductID		TINYINT
		, RealProductID TINYINT
		, IsCredit		BIT DEFAULT(0)
	)

	--Sports have setting by customer
	--INSERT INTO #SportsNonOffered(SportType, BetType, ProductID, RealProductID, IsCredit)
	--SELECT DISTINCT f.SportType, f.BetType, ProductID, RealProductID, 1 AS IsCredit
	--FROM dbo.f_CustSetting_ProductSettingDetailSel(@SettingStatus) f
	--INNER JOIN ProductSettingType st WITH (NOLOCK) ON f.SettingType=st.SettingType
	--WHERE st.SettingName = 'Bet Setting'
	--	OR st.SettingName = 'Stake Level'
	--UNION ALL
	--SELECT DISTINCT f.SportType, f.BetType, ProductID, ProductID, 0 AS IsCredit
	--FROM dbo.f_Dep_CustSetting_SportBetTypeSettingSelect_UAT1(NULL, NULL,@SettingStatus) f
	--INNER JOIN Dep_ProductSettingType st WITH (NOLOCK) ON f.SettingType=st.SettingType
	--WHERE st.SettingName='Bet Setting'
	-- OR st.SettingName='Stake Level'

	
	--#NewInputDataTbl
	INSERT INTO #NewInputDataTbl(RowID, SportType, CurrencyGroupID,
								 GameGroupID, SiteID,
								 NewMinBet, NewMaxBet, NewRemark,
								 CurMinBet, CurMaxBet, CurRemark,
								 IsCredit)
	SELECT	RowID, SportType, CreditGroupID,
			GameGroupID, SiteID,
			NewMinBet, NewMaxBet, NewRemark,
			CurMinBet, CurMaxBet, CurRemark, 1 AS IsCredit
	FROM @NewGlobalTbl nsl
	WHERE ISNULL(nsl.CreditGroupID,'')<>''
	UNION ALL
	SELECT	RowID, SportType, LicenseeGroupID,
			GameGroupID, SiteID,
			NewMinBet, NewMaxBet, NewRemark,
			CurMinBet, CurMaxBet, CurRemark, 0 AS IsCredit
	FROM @NewGlobalTbl nsl
	WHERE ISNULL(nsl.LicenseeGroupID,'')<>''

	--------------------------------------------------------------------------------------------------------------------------------------
	SELECT TOP (1)
			@ErrCode=CASE 
						WHEN NewMinBet=0									THEN 108
						WHEN NewMaxBet=0									THEN 109
						WHEN NewMinBet > NewMaxBet							THEN 110
						WHEN CurMinBet > CurMaxBet							THEN 111
						WHEN CurMinBet IS NULL AND CurMaxBet IS NOT NULL	THEN 112
						WHEN CurMinBet IS NOT NULL AND CurMaxBet IS NULL	THEN 113
																			ELSE 107 
					END
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=CASE
							WHEN NewMinBet=0 			THEN ': The Min Bet must be different from 0.'
							WHEN NewMaxBet=0			THEN ': The Max Bet must be different from 0.'
							WHEN NewMinBet > NewMaxBet	THEN ': The New Min Bet must be less than or equal to the Current Max Bet.'
							WHEN CurMinBet > CurMaxBet	THEN ': The Current Min Bet must be less than or equal to the Current Max Bet.'
							WHEN CurMinBet IS NULL AND CurMaxBet IS NOT NULL	THEN ': You input missing data with the product''s format. Please input data on Current Min Bet.'
							WHEN CurMinBet IS NOT NULL AND CurMaxBet IS NULL	THEN ': You input missing data with the product''s format. Please input data on Current Max Bet.'
							ELSE '' 
							END 						  
	FROM #NewInputDataTbl t
	WHERE NewMinBet=0 OR NewMaxBet=0
		OR (CurMinBet IS NULL AND CurMaxBet IS NOT NULL)
		OR (CurMinBet IS NOT NULL AND CurMaxBet IS NULL)
		OR NewMinBet > NewMaxBet 
		OR CurMinBet > CurMaxBet
		
	IF @ErrCode<>0
		GOTO SetErr

	--------------------------------------------------------------------------------------------------------------------------------------
	--Sporttype
	SELECT TOP(1)
			@ErrCode=114 
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=': The Sport Type ' + CAST (t.SportType AS varchar) + ' does not exist.'				
	FROM #NewInputDataTbl t
	LEFT JOIN #Sports s ON s.SportType=t.SportType 
	WHERE s.SportType IS NULL

	IF @ErrCode=114			
		GOTO SetErr

	--Sports not offered
	SELECT TOP(1) 
			@ErrCode=119
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=': Bet Limit of ' + s.SportName + ' is not allowed to be imported.'
	FROM #NewInputDataTbl t
	INNER JOIN #Sports s ON s.SportType=t.SportType
	INNER JOIN #SportsNonOffered non ON non.SportType=t.SportType
									AND non.IsCredit=t.IsCredit

	IF @ErrCode=119			
		GOTO SetErr

	--CurrencyGroupID
	SELECT TOP(1) 
			@ErrCode=115
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=CASE WHEN t.IsCredit=1 AND ce.CreditGroupID IS NULL   THEN ': Credit Group ID ' 
							  WHEN t.IsCredit=0 AND de.LicenseeGroupID IS NULL THEN ': Licensee Group ID ' 
						  END
						+ CAST (t.CurrencyGroupID AS varchar) 
						+ ' does not exist.'				
	FROM #NewInputDataTbl t
	OUTER APPLY (SELECT ce.CreditGroupID FROM Exchange ce WITH (NOLOCK)
				 WHERE ce.CreditGroupID=t.CurrencyGroupID
				 AND t.IsCredit=1) ce
	OUTER APPLY (SELECT de.LicenseeGroupID FROM Exchange de WITH (NOLOCK)
				 WHERE de.LicenseeGroupID=t.CurrencyGroupID
				 AND t.IsCredit=0) de
	WHERE (t.IsCredit=1 AND ce.CreditGroupID IS NULL)
		OR (t.IsCredit=0 AND de.LicenseeGroupID IS NULL)

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
						+ CAST (t.GameGroupID AS varchar) 
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
						+ CAST (t.SiteID AS varchar) 
						+ ' does not exist.'				
	FROM #NewInputDataTbl t 
	LEFT JOIN Site s WITH (NOLOCK) ON s.siteid=t.SiteID
	WHERE t.SiteID<>0 AND t.IsCredit=0
		AND s.siteid IS NULL

	IF @ErrCode=117			
		GOTO SetErr

	SELECT TOP(1) 
			@ErrCode=118
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=': Can not import Global Deposit Settings for specific Credit site.'
	FROM #NewInputDataTbl t 
	INNER JOIN Site s WITH (NOLOCK) ON s.siteid=t.SiteID
	WHERE t.SiteID<>0 AND t.IsCredit=0		--Deposit setting lines
		AND s.siteid IS NOT NULL AND s.isDeposit=0	--credit site

	IF @ErrCode=118			
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
						) 
					AND IsCredit=1
				)
			OR
				(EXISTS (SELECT TOP 1 1 FROM Dep_ProductStakeLevelGroup psl WITH (NOLOCK)
						 WHERE t.SportType=psl.Sporttype
						 AND t.GameGroupID=psl.GameGroupID
						 AND t.CurrencyGroupID=psl.LicenseeGroupID
						 AND t.SiteID=psl.SiteID
						) 
					AND IsCredit=0
				)
			)

	IF @ErrCode=120			
		GOTO SetErr

	--does not have any existing bet limit with Current values
	SELECT TOP(1) 
			@ErrCode=121
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=': Sport Type ' + CAST (t.SportType AS varchar)
						+ ' does not have any existing bet limit with Current Min Bet: ' + CAST (t.CurMinBet AS varchar)
						+ ', Current Max Bet: ' + CAST (t.CurMaxBet AS varchar)
	FROM #NewInputDataTbl t 
	WHERE t.CurMinBet IS NOT NULL AND t.CurMaxBet IS NOT NULL
		AND (
			(NOT EXISTS (SELECT TOP 1 1 FROM ProductStakeLevelGroup psl WITH (NOLOCK)
						WHERE t.SportType=psl.Sporttype
						AND t.GameGroupID=psl.GameGroupID
						AND t.CurrencyGroupID=psl.CreditGroupID
						AND t.CurMinBet=psl.MinBet
						AND t.CurMaxBet=psl.MaxBet
						) 
					AND IsCredit=1)
			OR
			(NOT EXISTS (SELECT TOP 1 1 FROM Dep_ProductStakeLevelGroup psl WITH (NOLOCK)
						WHERE t.SportType=psl.Sporttype
						AND t.GameGroupID=psl.GameGroupID
						AND t.CurrencyGroupID=psl.LicenseeGroupID
						AND t.SiteID=psl.SiteID
						AND t.CurMinBet=psl.MinBet
						AND t.CurMaxBet=psl.MaxBet
						) 
					AND IsCredit=0)
			)

	IF @ErrCode=121			
		GOTO SetErr

	--The same: new - current value
	SELECT TOP(1) 
			@ErrCode=122
			,@RowError=CAST(t.RowID AS VARCHAR(5))
			,@ValueError=': The New Min Bet, New Max Bet are the same as The Current Min Bet, the Current Max Bet. Please input another value for the New values again.'
	FROM #NewInputDataTbl t 
	WHERE t.CurMinBet=t.NewMinBet AND t.CurMaxBet=t.NewMaxBet

	IF @ErrCode=122			
		GOTO SetErr

	--RowDuplicate
	INSERT INTO #RowDuplicate(RowIDF, RowIDT)
	SELECT DISTINCT t.RowID , ndt.RowID
	FROM #NewInputDataTbl t
	INNER JOIN #NewInputDataTbl ndt 
			ON t.SportType = ndt.SportType 
			AND t.GameGroupID = ndt.GameGroupID 
			AND t.CurrencyGroupID = ndt.CurrencyGroupID 
			AND (t.IsCredit = ndt.IsCredit AND (t.IsCredit=1 OR (t.IsCredit=0 AND t.SiteID=ndt.SiteID)))
			AND ISNULL(t.CurMinBet,0) = ISNULL(ndt.CurMinBet,0) AND ISNULL(t.CurMaxBet,0)=ISNULL(ndt.CurMaxBet,0) 
			AND t.NewMaxBet = ndt.NewMaxBet AND t.NewMinBet = ndt.NewMinBet  
	WHERE t.RowID < ndt.RowID
	
	IF EXISTS (SELECT TOP 1 1 FROM #RowDuplicate)			
	BEGIN
		SET @ErrCode=123
		
		SELECT @ValueError=STUFF((SELECT ', Row ' + CAST(RowIDF AS NVARCHAR(50)) + ' - Row ' + CAST(RowIDT AS NVARCHAR(50)) 
								FROM #RowDuplicate tmp
								ORDER BY RowIDF
								FOR XML PATH('')), 1, 1, '') + ': These rows have duplicate data' 
		GOTO SetErr
	END	

	--Upload more than 1 setting line with the same primary keys
	--Duplicate setting
	;WITH NewInputDataTbl AS (
		SELECT DISTINCT
			RowID, SportType
			, CurrencyGroupID, GameGroupID
			, SiteID, IsCredit
		FROM #NewInputDataTbl t 
	)
	INSERT INTO #SettingDuplicate (SettingRows)
	SELECT STUFF((STUFF((SELECT ' - Row ' + CAST(RowID AS VARCHAR(5))
						 FROM NewInputDataTbl b
						 WHERE a.SportType=b.SportType
						 AND a.CurrencyGroupID=b.CurrencyGroupID
						 AND a.GameGroupID=b.GameGroupID 
						 AND a.IsCredit = b.IsCredit 
						 FOR XML PATH('')), 1, 1, '')),1,2,'') AS t
	FROM #NewInputDataTbl a
	WHERE a.IsCredit=1
	GROUP BY SportType, CurrencyGroupID, GameGroupID, IsCredit
	HAVING COUNT(1)>1
	UNION
	SELECT STUFF((STUFF((SELECT ' - Row ' + CAST(RowID AS VARCHAR(5))
						 FROM NewInputDataTbl b
						 WHERE a.SportType=b.SportType
						 AND a.CurrencyGroupID=b.CurrencyGroupID
						 AND a.GameGroupID=b.GameGroupID 
						 AND a.SiteID = b.SiteID 
						 AND a.IsCredit = b.IsCredit 
						 FOR XML PATH('')), 1, 1, '')),1,2,'') AS t
	FROM #NewInputDataTbl a
	WHERE a.IsCredit=0
	GROUP BY SportType, CurrencyGroupID, GameGroupID, SiteID, IsCredit
	HAVING COUNT(1)>1

	IF EXISTS (SELECT TOP 1 1 FROM #SettingDuplicate)			
	BEGIN
		SELECT @ErrCode=124
		SELECT @ValueError=STUFF((SELECT ', ' + SettingRows 
								FROM #SettingDuplicate t
								FOR XML PATH('')), 1, 1, '') + ': You can only upload 1 set of setting values. Please remove redundant data row(s).' 

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
		WHERE a.IsCredit=1 
			AND (EXISTS (SELECT TOP 1 1 FROM ProductStakeLevelGroup slg WITH(NOLOCK) 
						 WHERE slg.Sporttype=a.SportType AND slg.GameGroupID=a.GameGroupID
							AND slg.CreditGroupID=a.CurrencyGroupID
							AND (a.NewMinBet=slg.MinBet AND a.NewMaxBet=slg.MaxBet)))
		UNION ALL
		SELECT RowID 
		FROM #NewInputDataTbl a
		WHERE a.IsCredit=0 
			AND (EXISTS (SELECT TOP 1 1 FROM Dep_ProductStakeLevelGroup slg WITH(NOLOCK) 
						 WHERE slg.Sporttype=a.SportType AND slg.GameGroupID=a.GameGroupID
							AND slg.LicenseeGroupID=a.CurrencyGroupID 
							AND slg.SiteID=a.SiteID
							AND (a.NewMinBet=slg.MinBet AND a.NewMaxBet=slg.MaxBet)))
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