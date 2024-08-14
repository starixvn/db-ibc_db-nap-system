/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_GlobalStakeLevelGroup_Sel] 
	-- Add the parameters for the stored procedure here
	 @pMutilProductID	VARCHAR(MAX) = '0'
	 ,@pMutilCurrency	VARCHAR(MAX) = '0'
	 ,@pMutilSite		VARCHAR(MAX) = ''
	 ,@IsCredit			BIT=1
AS
/*
	Created: 20230914@Tacy
	Task : 3rd Products - Simplify RNG Games bet limit setting
	DB: DBACC/bodb02

	Revisions:
		- 20220705@Tacy: Initalize SP [RedmineID: #194332]
		- 20240624@Tacy: Implement more function [Redmine: #196256]

	Param's Explanation:
		@pMutilProductID = 0 : All 
						<> 0 : ProductID

		@pMutilCurrency	 = 0 : All 
						<> 0 : Currency
*/
BEGIN
	SET NOCOUNT ON;

	IF @pMutilCurrency='' OR @pMutilProductID=''
		RETURN

	CREATE TABLE #ExchangeGroup (
			CreditGroupID TINYINT,
			LicenseeGroupID TINYINT)

	CREATE TABLE #Sports(
			SportType SMALLINT PRIMARY KEY, 
			SportName VARCHAR(50)
		)

	CREATE TABLE #GlobalStakeLevelGroup (
		Sporttype		SMALLINT,
		Sportname		VARCHAR(50),
		GameGroupID		TINYINT,
		GameGroup		VARCHAR(50),
		MinBet			MONEY,
		MaxBet			MONEY,
		CurrencyGroupID TINYINT,
		ExchangeID		INT,
		SiteID			INT DEFAULT (0),
		Remark			VARCHAR(1000)
	)

	INSERT INTO #Sports (SportType, SportName)	
	EXEC Acc_SporttypeSel @Mode=1

	INSERT INTO #ExchangeGroup (CreditGroupID, LicenseeGroupID)
	SELECT DISTINCT CreditGroupID, LicenseeGroupID
	FROM Exchange e WITH(NOLOCK)
	WHERE IsActive = 1 AND ((@IsCredit = 1 AND OfferSite IN (0,1)) OR (@IsCredit = 0 AND OfferSite IN (0,2)))
	AND (@pMutilCurrency = '0' OR e.ExchangeId IN (SELECT TRIM(value) val FROM STRING_SPLIT(@pMutilCurrency, ',')))

	IF @IsCredit=1
	BEGIN
		INSERT INTO #GlobalStakeLevelGroup(Sporttype, Sportname, CurrencyGroupID, ExchangeID, GameGroupID, GameGroup, MinBet, MaxBet, Remark)
		SELECT DISTINCT
			psl.SportType, s.SportName, ex.CreditGroupID, ex.ExchangeId
			, psl.GameGroupID
			, CASE WHEN psl.GameGroupID=1 THEN 'Slot Game' 
				   WHEN psl.GameGroupID=2 THEN 'Others'
			END AS GameGroup
			, psl.MinBet, psl.MaxBet, psl.Remark
		FROM ProductStakeLevelGroup psl WITH (NOLOCK)
			INNER JOIN #ExchangeGroup eg WITH (NOLOCK) ON eg.CreditGroupID=psl.CreditGroupID
			INNER JOIN Exchange ex WITH (NOLOCK) ON ex.CreditGroupID=eg.CreditGroupID
			CROSS APPLY (SELECT TOP 1 
							sm.SportTypeRefBetSetting AS SportType
							,sm.RealProductId AS ProductID
						 FROM SportBettypeSettingMatrix sm WITH (NOLOCK)
						 WHERE psl.SportType=sm.SportTypeRefBetSetting 
							AND sm.isDeleted=0 AND isLicensee=0 AND isActive=1) sp
			INNER JOIN #Sports s ON s.SportType=sp.SportType
		WHERE psl.IsDeleted=0
		AND (@pMutilProductID = '0' OR sp.ProductID IN (SELECT TRIM(value) val FROM STRING_SPLIT(@pMutilProductID, ',')))
	END
	ELSE
	BEGIN
		INSERT INTO #GlobalStakeLevelGroup(Sporttype, Sportname, CurrencyGroupID, ExchangeID, SiteID, GameGroupID, GameGroup, MinBet, MaxBet, Remark)
		SELECT DISTINCT
			psl.SportType, s.SportName, ex.LicenseeGroupID, ex.ExchangeId
			, psl.SiteID
			, psl.GameGroupID
			, CASE WHEN psl.GameGroupID=1 THEN 'Slot Game' 
				   WHEN psl.GameGroupID=2 THEN 'Others'
			END AS GameGroup
			, psl.MinBet, psl.MaxBet, psl.Remark
		FROM Dep_ProductStakeLevelGroup psl WITH (NOLOCK)
			LEFT JOIN Site sS WITH (NOLOCK) ON sS.siteid=psl.SiteID
			INNER JOIN #ExchangeGroup eg WITH (NOLOCK) ON eg.LicenseeGroupID=psl.LicenseeGroupID
			INNER JOIN Exchange ex WITH (NOLOCK) ON ex.LicenseeGroupID=eg.LicenseeGroupID
			CROSS APPLY (SELECT TOP 1 
							sm.SportTypeRefBetSetting AS SportType
							,sm.RealProductId AS ProductID
						 FROM SportBettypeSettingMatrix sm WITH (NOLOCK)
						 WHERE psl.SportType=sm.SportTypeRefBetSetting 
							AND sm.isDeleted=0 AND isLicensee=1 AND isActive=1) sp
			INNER JOIN #Sports s ON s.SportType=sp.SportType
		WHERE psl.IsDeleted=0
		AND (@pMutilProductID = '0' OR sp.ProductID IN (SELECT TRIM(value) val FROM STRING_SPLIT(@pMutilProductID, ',')))
		AND (@pMutilSite = '' OR PSL.SiteID IN (SELECT TRIM(value) val FROM STRING_SPLIT(@pMutilSite, ',')))
	END

	SELECT Sporttype, Sportname
		, CurrencyGroupID, ExchangeID
		, SiteID
		, GameGroupID
		, GameGroup
		, MinBet, MaxBet, Remark
	FROM #GlobalStakeLevelGroup
	ORDER BY Sportname, CurrencyGroupID, SiteID, GameGroup DESC

	DROP TABLE #GlobalStakeLevelGroup, #Sports, #ExchangeGroup
END
GO