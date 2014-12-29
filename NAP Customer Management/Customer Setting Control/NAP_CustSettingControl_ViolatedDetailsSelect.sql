ALTER PROCEDURE [dbo].[NAP_CustSettingControl_ViolatedDetailsSelect] 
	  @CustID INT
	, @SiteID INT
	, @Currency INT
	, @RoleID TINYINT
	, @Mode TINYINT
AS
/*	Created by: Dominic
	Date: 20141229
	Task: Display a detailed violated PotsitonTaking Policy list of a customer
	DB: DBACC/bodb02
	*Parameters:
		- @Mode: 1-Violated SuperMax 2-Violated MasterMax 3-Violated AgentMax
	*Revisions:
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #SportBetTypeMapping (
		SportType SMALLINT
		, BetType SMALLINT
		, ProductID TINYINT DEFAULT(1)
		, IsDisabled BIT DEFAULT(0)
		)

	DECLARE @ViolatedSetting TABLE (
		SportType SMALLINT
		, BetType SMALLINT
		, ProductID TINYINT
		, SuperMax SMALLMONEY
		, MasterMax SMALLMONEY
		, AgentMax SMALLMONEY
		)

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
	WHERE SportType BETWEEN 151 AND 153

	--NG
	UPDATE #SportBetTypeMapping
	SET ProductID = 3
	WHERE SportType = 161
		AND BetType BETWEEN 81 AND 120

	--LC
	UPDATE #SportBetTypeMapping
	SET ProductID = 4
	WHERE SportType = 162 AND BetType = 1101

	--VS
	UPDATE #SportBetTypeMapping
	SET ProductID = 5
	WHERE SportType IN (180, 181, 182, 183, 184, 185, 186) AND BetType IN (1201, 1231, 1220)

	--KN
	UPDATE #SportBetTypeMapping
	SET ProductID = 8
	WHERE BetType BETWEEN 1501 AND 1599 AND SportType = 202

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
	FROM #SportBetTypeMapping main
	INNER JOIN dbo.CustInfo ci WITH(NOLOCK)
		ON ci.CustID = @CustID
	WHERE main.ProductID IN (2, 3, 4, 5)

	--Update Keno's status
	UPDATE main
	SET main.IsDisabled = CASE 
			WHEN EXISTS (
					SELECT TOP 1 1
					FROM dbo.CustGameType gt WITH (NOLOCK)
					WHERE gt.CustID = @CustID
						AND gt.IsDisabled = 0
					)
				THEN 0
			ELSE 1
			END
	FROM #SportBetTypeMapping main
	WHERE main.ProductID = 8

	CREATE CLUSTERED INDEX IDX_sporttype_bettype ON #SportBetTypeMapping (
		sporttype
		, bettype
		)

	--SB - Deadball
	INSERT @ViolatedSetting
	SELECT cs.sporttype
		, cs.bettype
		, p.ProductID
		, cs.spositiontaking SuperMax
		, cs.mpositiontaking MasterMax
		, cs.apositiontaking AgentMax
	FROM dbo.CustSetting cs WITH(NOLOCK)
	INNER JOIN #SportBetTypeMapping mp
		ON mp.SportType = cs.SportType
			AND mp.BetType = cs.BetType
	INNER JOIN dbo.PTSettingPolicy p WITH(NOLOCK)
		ON p.SiteID = @SiteID
			AND p.ExchangeID = @Currency
			AND p.RoleID = @RoleID
			AND p.ProductID = mp.ProductID
	WHERE cs.CustID = @CustID
		AND mp.IsDisabled = 0
		AND (
			(
				p.AgentMax IS NOT NULL
				AND cs.apositiontaking <> p.AgentMax
				)
			OR (
				p.MasterMax IS NOT NULL
				AND cs.mpositiontaking <> p.MasterMax
				)
			OR (
				p.SuperMax IS NOT NULL
				AND cs.spositiontaking <> p.SuperMax
				)
			)

	--SB - Liveball
	INSERT @ViolatedSetting
	SELECT cs.sporttype
		, cs.bettype
		, p.ProductID
		, cs.slivepositiontaking SuperMax
		, cs.mlivepositiontaking MasterMax
		, cs.alivepositiontaking AgentMax
	FROM dbo.CustSetting cs WITH(NOLOCK)
	INNER JOIN #SportBetTypeMapping mp
		ON mp.SportType = cs.SportType
			AND mp.BetType = cs.BetType
	INNER JOIN dbo.PTSettingPolicy p WITH(NOLOCK)
		ON p.SiteID = @SiteID
			AND p.ExchangeID = @Currency
			AND p.RoleID = @RoleID
			AND p.ProductID = mp.ProductID
	WHERE cs.CustID = @CustID
		AND mp.IsDisabled = 0
		AND cs.SportType = 1
		AND cs.BetType IN (1, 3, 7, 8)
		AND (
			(
				p.AgentMax IS NOT NULL
				AND cs.alivepositiontaking <> p.AgentMax
				)
			OR (
				p.MasterMax IS NOT NULL
				AND cs.mlivepositiontaking <> p.MasterMax
				)
			OR (
				p.SuperMax IS NOT NULL
				AND cs.slivepositiontaking <> p.SuperMax
				)
			)

	--NG(Deadball),RC,VS
	INSERT @ViolatedSetting
	SELECT cs.sporttype
		, cs.bettype
		, p.ProductID
		, cs.spositiontaking SuperMax
		, cs.mpositiontaking MasterMax
		, cs.apositiontaking AgentMax
	FROM dbo.CustSetting3rd cs WITH(NOLOCK)
	INNER JOIN #SportBetTypeMapping mp
		ON mp.SportType = cs.SportType
			AND mp.BetType = cs.BetType
	INNER JOIN dbo.PTSettingPolicy p WITH(NOLOCK)
		ON p.SiteID = @SiteID 
			AND p.ExchangeID = @Currency
			AND p.RoleID = @RoleID
			AND p.ProductID = mp.ProductID
	WHERE cs.CustID = @CustID
		AND mp.IsDisabled = 0
		AND (
			(
				p.AgentMax IS NOT NULL
				AND cs.apositiontaking <> p.AgentMax
				)
			OR (
				p.MasterMax IS NOT NULL
				AND cs.mpositiontaking <> p.MasterMax
				)
			OR (
				p.SuperMax IS NOT NULL
				AND cs.spositiontaking <> p.SuperMax
				)
			)

	--NG - Liveball
	INSERT @ViolatedSetting
	SELECT cs.sporttype
		, cs.bettype
		, p.ProductID
		, cs.slivepositiontaking SuperMax
		, cs.mlivepositiontaking MasterMax
		, cs.alivepositiontaking AgentMax
	FROM dbo.CustSetting3rd cs WITH(NOLOCK)
	INNER JOIN #SportBetTypeMapping mp
		ON mp.SportType = cs.SportType
			AND mp.BetType = cs.BetType
	INNER JOIN dbo.PTSettingPolicy p WITH(NOLOCK)
		ON p.SiteID = @SiteID
			AND p.ExchangeID = @Currency
			AND p.RoleID = @RoleID
			AND p.ProductID = mp.ProductID
	WHERE cs.CustID = @CustID
		AND mp.IsDisabled = 0
		AND cs.SportType = 161
		AND cs.BetType IN (85, 86, 87, 89, 90)
		AND (
			(
				p.AgentMax IS NOT NULL
				AND cs.alivepositiontaking <> p.AgentMax
				)
			OR (
				p.MasterMax IS NOT NULL
				AND cs.mlivepositiontaking <> p.MasterMax
				)
			OR (
				p.SuperMax IS NOT NULL
				AND cs.slivepositiontaking <> p.SuperMax
				)
			)

	--LC,KN
	INSERT @ViolatedSetting
	SELECT cs.sporttype
		, cs.bettype
		, p.ProductID
		, cs.spositiontaking SuperMax
		, cs.mpositiontaking MasterMax
		, cs.apositiontaking AgentMax
	FROM dbo.CustSettingGame cs WITH(NOLOCK)
	INNER JOIN #SportBetTypeMapping mp
		ON mp.SportType = cs.SportType
			AND mp.BetType = cs.BetType
	INNER JOIN dbo.PTSettingPolicy p WITH(NOLOCK)
		ON p.SiteID = @SiteID
			AND p.ExchangeID = @Currency
			AND p.RoleID = @RoleID
			AND p.ProductID = mp.ProductID
	WHERE cs.CustID = @CustID
		AND mp.IsDisabled = 0
		AND (
			(
				p.AgentMax IS NOT NULL
				AND cs.apositiontaking <> p.AgentMax
				)
			OR (
				p.MasterMax IS NOT NULL
				AND cs.mpositiontaking <> p.MasterMax
				)
			OR (
				p.SuperMax IS NOT NULL
				AND cs.spositiontaking <> p.SuperMax
				)
			)

	--Return Final results
	IF @RoleID = 4
	BEGIN
		IF @Mode = 1
		BEGIN
			SELECT p.ProductID
				, v.SportType
				, v.BetType
				, CASE WHEN p.SuperMax <> v.SuperMax THEN v.SuperMax ELSE p.SuperMax END SuperMax
				, CASE WHEN p.SuperMax <> v.SuperMax THEN 1 ELSE 0 END SDiff
				, CASE WHEN p.MasterMax <> v.MasterMax THEN v.MasterMax ELSE p.MasterMax END MasterMax
				, CASE WHEN p.MasterMax <> v.MasterMax THEN 1 ELSE 0 END MDiff
				, CASE WHEN p.AgentMax <> v.AgentMax THEN v.AgentMax ELSE p.AgentMax END AgentMax
				, CASE WHEN p.AgentMax <> v.AgentMax THEN 1 ELSE 0 END ADiff
			FROM @ViolatedSetting v
			INNER JOIN dbo.PTSettingPolicy p WITH(NOLOCK)
				ON p.SiteID = @SiteID
					AND p.ExchangeID = @Currency
					AND p.RoleID = @RoleID
					AND p.ProductID = v.ProductID
			WHERE p.SuperMax <> v.SuperMax
			ORDER BY p.ProductID
				, v.sporttype
				, v.bettype
		END
		ELSE IF @Mode = 2
		BEGIN
			SELECT p.ProductID
				, v.SportType
				, v.BetType
				, CASE WHEN p.SuperMax <> v.SuperMax THEN v.SuperMax ELSE p.SuperMax END SuperMax
				, CASE WHEN p.SuperMax <> v.SuperMax THEN 1 ELSE 0 END SDiff
				, CASE WHEN p.MasterMax <> v.MasterMax THEN v.MasterMax ELSE p.MasterMax END MasterMax
				, CASE WHEN p.MasterMax <> v.MasterMax THEN 1 ELSE 0 END MDiff
				, CASE WHEN p.AgentMax <> v.AgentMax THEN v.AgentMax ELSE p.AgentMax END AgentMax
				, CASE WHEN p.AgentMax <> v.AgentMax THEN 1 ELSE 0 END ADiff
			FROM @ViolatedSetting v
			INNER JOIN dbo.PTSettingPolicy p WITH(NOLOCK)
				ON p.SiteID = @SiteID
					AND p.ExchangeID = @Currency
					AND p.RoleID = @RoleID
					AND p.ProductID = v.ProductID
			WHERE p.MasterMax <> v.MasterMax
			ORDER BY p.ProductID
				, v.sporttype
				, v.bettype
		END
		ELSE IF @Mode = 3
		BEGIN
			SELECT p.ProductID
				, v.SportType
				, v.BetType
				, CASE WHEN p.SuperMax <> v.SuperMax THEN v.SuperMax ELSE p.SuperMax END SuperMax
				, CASE WHEN p.SuperMax <> v.SuperMax THEN 1 ELSE 0 END SDiff
				, CASE WHEN p.MasterMax <> v.MasterMax THEN v.MasterMax ELSE p.MasterMax END MasterMax
				, CASE WHEN p.MasterMax <> v.MasterMax THEN 1 ELSE 0 END MDiff
				, CASE WHEN p.AgentMax <> v.AgentMax THEN v.AgentMax ELSE p.AgentMax END AgentMax
				, CASE WHEN p.AgentMax <> v.AgentMax THEN 1 ELSE 0 END ADiff
			FROM @ViolatedSetting v
			INNER JOIN dbo.PTSettingPolicy p WITH(NOLOCK)
				ON p.SiteID = @SiteID
					AND p.ExchangeID = @Currency
					AND p.RoleID = @RoleID
					AND p.ProductID = v.ProductID
			WHERE p.AgentMax <> v.AgentMax
			ORDER BY p.ProductID
				, v.sporttype
				, v.bettype
		END
	END
	ELSE
	BEGIN
		SELECT p.ProductID
			, v.SportType
			, v.BetType
			, CASE WHEN p.SuperMax <> v.SuperMax THEN v.SuperMax ELSE p.SuperMax END SuperMax
				, CASE WHEN p.SuperMax <> v.SuperMax THEN 1 ELSE 0 END SDiff
				, CASE WHEN p.MasterMax <> v.MasterMax THEN v.MasterMax ELSE p.MasterMax END MasterMax
				, CASE WHEN p.MasterMax <> v.MasterMax THEN 1 ELSE 0 END MDiff
				, CASE WHEN p.AgentMax <> v.AgentMax THEN v.AgentMax ELSE p.AgentMax END AgentMax
				, CASE WHEN p.AgentMax <> v.AgentMax THEN 1 ELSE 0 END ADiff
		FROM @ViolatedSetting v
		INNER JOIN dbo.PTSettingPolicy p WITH(NOLOCK)
			ON p.SiteID = @SiteID
				AND p.ExchangeID = @Currency
				AND p.RoleID = @RoleID
				AND p.ProductID = v.ProductID
		ORDER BY p.ProductID
			, v.sporttype
			, v.bettype
	END

	DROP TABLE #SportBetTypeMapping
END
