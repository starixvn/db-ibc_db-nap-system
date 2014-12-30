ALTER PROCEDURE [dbo].[NAP_CustSettingControl_ViolatedDownlineSelect] 
	  @CustID	INT
	, @SiteID	INT
	, @Currency INT
	, @RoleID	TINYINT
AS
/*	Created by: Dominic
	Date: 20141224
	Task: Display a list of violated PotsitonTaking Policy SMA
	DB: DBACC/bodb02
	*Parameters:
		- @CustID: Super's CustID
		- @RoleID: Violated downlines' level
	*Revisions:
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #SuperDownline (
		CustID INT
		, MasterID INT
		)

	CREATE TABLE #SportBetTypeMapping (
		SportType SMALLINT
		, BetType SMALLINT
		, ProductID TINYINT DEFAULT(1)
		)

	CREATE TABLE #ViolatedDownlines (
		CustID INT
		, MasterID INT
		, UserName NVARCHAR(50)
		, MUserName NVARCHAR(50)
		, SportType SMALLINT
		, SportName NVARCHAR(50)
		, BetType SMALLINT
		, BetName NVARCHAR(50)
		, ProductID TINYINT
		, IsDisabled BIT DEFAULT(0)
		)

	--Get downline
	INSERT #SuperDownline (
		CustID
		, MasterID
		)
	SELECT CustID
		, mrecommend
	FROM dbo.Custinfo ci WITH (NOLOCK)
	WHERE ci.srecommend = @CustID
		AND ci.RoleID = @RoleID

	CREATE CLUSTERED INDEX IDX_CustID ON #SuperDownline (CustID)

	--Create Sporttype/Bettype mapping data
	INSERT #SportBetTypeMapping (
		SportType
		, BetType
		)
	SELECT SportType
		, BetType
	FROM dbo.CustSetting WITH (NOLOCK)
	WHERE CustID = @CustID
	
	UNION ALL
	
	SELECT SportType
		, BetType
	FROM dbo.CustSetting3rd WITH (NOLOCK)
	WHERE CustID = @CustID
	
	UNION ALL
	
	SELECT SportType
		, BetType
	FROM dbo.custsettingGame WITH (NOLOCK)
	WHERE CustID = @CustID

	--RC
	UPDATE #SportBetTypeMapping
	SET ProductID = 2
	WHERE SportType BETWEEN 151
			AND 153

	--NG
	UPDATE #SportBetTypeMapping
	SET ProductID = 3
	WHERE SportType = 161
		AND BetType BETWEEN 81
			AND 120

	--LC
	UPDATE #SportBetTypeMapping
	SET ProductID = 4
	WHERE SportType = 162
		AND BetType = 1101

	--VS
	UPDATE #SportBetTypeMapping
	SET ProductID = 5
	WHERE SportType IN (180, 181, 182, 183, 184, 185, 186)
		AND BetType IN (1201, 1231, 1220)

	--KN
	UPDATE #SportBetTypeMapping
	SET ProductID = 8
	WHERE BetType BETWEEN 1501
			AND 1599
		AND SportType = 202

	CREATE CLUSTERED INDEX IDX_sporttype_bettype ON #SportBetTypeMapping (
		sporttype
		, bettype
		)

	IF @RoleID = 2
	BEGIN
		--SB - Deadball
		INSERT #ViolatedDownlines(CustID,MasterID,SportType,BetType,ProductID)
		SELECT main.CustID
			, main.MasterID
			, cs.sporttype
			, cs.bettype
			, p.ProductID
		FROM dbo.CustSetting cs WITH(NOLOCK)
		JOIN #SuperDownline main ON main.CustID = cs.CustID
		JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
		JOIN dbo.PTSettingPolicy p
			ON p.SiteID = @SiteID
				AND p.ExchangeID = @Currency
				AND p.RoleID = 4
				AND p.ProductID = mp.ProductID
		WHERE (p.AgentMax IS NOT NULL AND cs.apositiontaking <> p.AgentMax)
				
		--SB - Liveball
		INSERT #ViolatedDownlines(CustID,MasterID,SportType,BetType,ProductID)
		SELECT main.CustID
			, main.MasterID
			, cs.sporttype
			, cs.bettype
			, p.ProductID
		FROM dbo.CustSetting cs
		JOIN #SuperDownline main ON main.CustID = cs.CustID
		JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
		JOIN dbo.PTSettingPolicy p
			ON p.SiteID = @SiteID
				AND p.ExchangeID = @Currency
				AND p.RoleID = 4
				AND p.ProductID = mp.ProductID
		WHERE (p.AgentMax IS NOT NULL AND cs.alivepositiontaking <> p.AgentMax)
				AND cs.SportType=1 AND cs.BetType IN (1,3,7,8)
			  
		--NG(Deadball),RC,VS
		INSERT #ViolatedDownlines(CustID,MasterID,SportType,BetType,ProductID)
		SELECT main.CustID
			, main.MasterID
			, cs.sporttype
			, cs.bettype
			, p.ProductID
		FROM dbo.CustSetting3rd cs
		JOIN #SuperDownline main ON main.CustID = cs.CustID
		JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
		JOIN dbo.PTSettingPolicy p
			ON p.SiteID = @SiteID
				AND p.ExchangeID = @Currency
				AND p.RoleID = 4
				AND p.ProductID = mp.ProductID
		WHERE (p.AgentMax IS NOT NULL AND cs.apositiontaking <> p.AgentMax)
				
		--NG - Liveball
		INSERT #ViolatedDownlines(CustID,MasterID,SportType,BetType,ProductID)
		SELECT main.CustID
			, main.MasterID
			, cs.sporttype
			, cs.bettype
			, p.ProductID
		FROM dbo.CustSetting3rd cs
		JOIN #SuperDownline main ON main.CustID = cs.CustID
		JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
		JOIN dbo.PTSettingPolicy p
			ON p.SiteID = @SiteID
				AND p.ExchangeID = @Currency
				AND p.RoleID = 4
				AND p.ProductID = mp.ProductID
		WHERE (p.AgentMax IS NOT NULL AND cs.alivepositiontaking <> p.AgentMax)
				AND cs.SportType=161 AND cs.BetType IN (85,86,87,89,90)

		--LC,KN
		INSERT #ViolatedDownlines(CustID,MasterID,SportType,BetType,ProductID)
		SELECT main.CustID
			, main.MasterID
			, cs.sporttype
			, cs.bettype
			, p.ProductID
		FROM dbo.CustSettingGame cs
		JOIN #SuperDownline main ON main.CustID = cs.CustID
		JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
		JOIN dbo.PTSettingPolicy p
			ON p.SiteID = @SiteID
				AND p.ExchangeID = @Currency
				AND p.RoleID = 4
				AND p.ProductID = mp.ProductID
		WHERE (p.AgentMax IS NOT NULL AND cs.apositiontaking <> p.AgentMax)
	END
	ELSE IF @RoleID = 3
	BEGIN
		--SB - Deadball
		INSERT #ViolatedDownlines(CustID,MasterID,SportType,BetType,ProductID)
		SELECT main.CustID
			, main.MasterID
			, cs.sporttype
			, cs.bettype
			, p.ProductID
		FROM dbo.CustSetting cs WITH(NOLOCK)
		JOIN #SuperDownline main ON main.CustID = cs.CustID
		JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
		JOIN dbo.PTSettingPolicy p
			ON p.SiteID = @SiteID
				AND p.ExchangeID = @Currency
				AND p.RoleID = 4
				AND p.ProductID = mp.ProductID
		WHERE (p.MasterMax IS NOT NULL AND cs.mpositiontaking  <> p.MasterMax)
				
		--SB - Liveball
		INSERT #ViolatedDownlines(CustID,MasterID,SportType,BetType,ProductID)
		SELECT main.CustID
			, main.MasterID
			, cs.sporttype
			, cs.bettype
			, p.ProductID
		FROM dbo.CustSetting cs
		JOIN #SuperDownline main ON main.CustID = cs.CustID
		JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
		JOIN dbo.PTSettingPolicy p
			ON p.SiteID = @SiteID
				AND p.ExchangeID = @Currency
				AND p.RoleID = 4
				AND p.ProductID = mp.ProductID
		WHERE (p.MasterMax IS NOT NULL AND cs.mlivepositiontaking  <> p.MasterMax)
				AND cs.SportType=1 AND cs.BetType IN (1,3,7,8)
			  
		--NG(Deadball),RC,VS
		INSERT #ViolatedDownlines(CustID,MasterID,SportType,BetType,ProductID)
		SELECT main.CustID
			, main.MasterID
			, cs.sporttype
			, cs.bettype
			, p.ProductID
		FROM dbo.CustSetting3rd cs
		JOIN #SuperDownline main ON main.CustID = cs.CustID
		JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
		JOIN dbo.PTSettingPolicy p
			ON p.SiteID = @SiteID
				AND p.ExchangeID = @Currency
				AND p.RoleID = 4
				AND p.ProductID = mp.ProductID
		WHERE (p.MasterMax IS NOT NULL AND cs.mpositiontaking  <> p.MasterMax)
				
		--NG - Liveball
		INSERT #ViolatedDownlines(CustID,MasterID,SportType,BetType,ProductID)
		SELECT main.CustID
			, main.MasterID
			, cs.sporttype
			, cs.bettype
			, p.ProductID
		FROM dbo.CustSetting3rd cs
		JOIN #SuperDownline main ON main.CustID = cs.CustID
		JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
		JOIN dbo.PTSettingPolicy p
			ON p.SiteID = @SiteID
				AND p.ExchangeID = @Currency
				AND p.RoleID = 4
				AND p.ProductID = mp.ProductID
		WHERE (p.MasterMax IS NOT NULL AND cs.mlivepositiontaking  <> p.MasterMax)
				AND cs.SportType=161 AND cs.BetType IN (85,86,87,89,90)

		--LC,KN
		INSERT #ViolatedDownlines(CustID,MasterID,SportType,BetType,ProductID)
		SELECT main.CustID
			, main.MasterID
			, cs.sporttype
			, cs.bettype
			, p.ProductID
		FROM dbo.CustSettingGame cs
		JOIN #SuperDownline main ON main.CustID = cs.CustID
		JOIN #SportBetTypeMapping mp ON mp.SportType = cs.SportType AND mp.BetType=cs.BetType
		JOIN dbo.PTSettingPolicy p
			ON p.SiteID = @SiteID
				AND p.ExchangeID = @Currency
				AND p.RoleID = 4
				AND p.ProductID = mp.ProductID
		WHERE (p.MasterMax IS NOT NULL AND cs.mpositiontaking  <> p.MasterMax)
	END

	--Update username
	UPDATE main
	SET main.UserName = c.UserName
		, main.MUserName = m.UserName
	FROM #ViolatedDownlines main
	INNER JOIN dbo.Customer c
		ON c.CustID = main.CustID
	INNER JOIN dbo.Customer m
		ON m.CustID = main.MasterID

	--Update SportType,BetType
	UPDATE main
	SET main.SportName = s.SportName
		, main.BetName = b.TypeNameE
	FROM #ViolatedDownlines main
	INNER JOIN dbo.Sports s
		ON main.SportType = s.SportType
	INNER JOIN dbo.BetType b
		ON main.BetType = b.TypeID

	--Update Product Status
	UPDATE main
	SET main.IsDisabled = CASE 
			WHEN main.ProductID = 2
				THEN (ci.Disable151_AU & ci.Disable152_AU & ci.Disable152_UK & ci.Disable153_AU & ci.DisableHorseRacing & ci.DisableOpenTote)
			WHEN main.ProductID = 3
				THEN ci.DisableNumber
			WHEN main.ProductID = 4
				THEN (~ ci.SyncLiveCasino | ci.DisableLiveCasino)
			WHEN main.ProductID = 5
				THEN ci.DisableVirtualSports
			END
	FROM #ViolatedDownlines main
	INNER JOIN dbo.CustInfo ci WITH (NOLOCK)
		ON ci.CustID = main.CustID
	WHERE main.ProductID IN (2, 3, 4, 5)

	--Update Keno's status
	UPDATE main
	SET main.IsDisabled = CASE 
			WHEN EXISTS (
					SELECT TOP 1 1
					FROM dbo.CustGameType gt WITH (NOLOCK)
					WHERE gt.CustID = main.CustID
						AND gt.IsDisabled = 0
					)
				THEN 0
			ELSE 1
			END
	FROM #ViolatedDownlines main
	WHERE main.ProductID = 8

	--Partion result for top errors
	SELECT CustID
		, UserName
		, MasterID
		, MUserName
		, SportName
		, BetName
		, ROW_NUMBER() OVER (
			PARTITION BY CustID ORDER BY SportType
				, BetType
			) AS Number
	INTO #FinalResult
	FROM (
		SELECT DISTINCT CustID
			, UserName
			, MasterID
			, MUserName
			, SportType
			, SportName
			, betType
			, BetName
		FROM #ViolatedDownlines
		WHERE IsDisabled = 0
		) tmp
	ORDER BY CustID
		, Number

	--Return final results
	SELECT CustID
		, UserName
		, MasterID
		, MUserName
		, STUFF((
				SELECT + ',   ' + CAST([SportName] AS VARCHAR(MAX)) + ' - ' + CAST([BetName] AS VARCHAR(MAX))
				FROM #FinalResult
				WHERE (custid = v.custid)
					AND Number <= 10
				ORDER BY custid
				FOR XML PATH('')
					, TYPE
				).value('(./text())[1]', 'VARCHAR(MAX)'), 1, 2, '') AS TopErr
		, COUNT(1) TotalErr
	FROM #FinalResult v
	GROUP BY UserName
		, MUserName
		, CustID
		, MasterID
	ORDER BY MasterID
		, CustID

	DROP TABLE #ViolatedDownlines

	DROP TABLE #SuperDownline

	DROP TABLE #SportBetTypeMapping

	DROP TABLE #FinalResult
END
