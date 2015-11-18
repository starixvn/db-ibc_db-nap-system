USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_PayoutTrans_SelPermission]    Script Date: 11/12/2015 11:38:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_PayoutTrans_SelPermission]
(
	@AdminId			INT				= 0
	, @PayoutControl	INT				= 14
	, @ErrCode 			INT 			= 0 OUTPUT
	, @ErrMsg 			NVARCHAR(200) 	= '' OUTPUT
)
AS
/*
Created: 20151012@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBEXT.bodb02
Original:
Revisions:
	- 20151012@bobby.nguyen: Initial
	- 20151113@bobby.nguyen: Include Testing Licensee 
	
Param's Explanation:
	- @AdminId: Id of admin user login
	- @PayoutControl: bitwise operator 3 bits[1:Boping-2:OneWorks-3:Credit]
	
	
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @BopingControl 		BIT
		, @OneWorksControl		BIT
		, @CreditControl		BIT
		
	DECLARE @tblSite			TABLE
	(
		SiteControl				VARCHAR(100)
		,SiteId					INT
		,SiteName				VARCHAR(100)
	)
	
	DECLARE @tblProduct			TABLE
	(
		ProductId				SMALLINT
		,ProductName			VARCHAR(100)
	)
	
	-- SELECT site control
	SELECT @BopingControl 	= (2 & @PayoutControl)
		, @OneWorksControl	= (4 & @PayoutControl)
		, @CreditControl	= (8 & @PayoutControl)

	-- SELECT product control
	INSERT INTO @tblProduct	
	SELECT 
		s.sporttype
		, s.ProductName
	FROM bodb02.[dbo].[f_ProductPayout] () s 
	WHERE ((@BopingControl 	= 1 OR  @OneWorksControl = 1) AND s.sporttype IN (205)) --Microgaming RNG Casino
		OR (@CreditControl 	= 1 AND s.sporttype IN (204)) --Colossus Bets
		
	
	IF(@BopingControl 		= 1
		OR @OneWorksControl = 1
	)
	BEGIN
		
		CREATE TABLE #LA_PartyList (PartyId int, PartyName varchar(100), BranchName varchar(100), ParentId int)
	
		-- SELECT site control
		INSERT INTO #LA_PartyList
		EXEC [bodb_licensee].dbo.LA_PartyListSel
			
		;WITH CTE_SiteGroup
		AS
		(
			SELECT PartyId, PartyName
			FROM #LA_PartyList
			WHERE ParentId = 0
		)
		,CTE_LicenseeSite 
		AS 
		(
			SELECT g.PartyName 	AS SiteControl
				, s.siteid
				, p.PartyName 	AS SiteName
			FROM CTE_SiteGroup g
				INNER JOIN #LA_PartyList p 
				ON g.PartyId = p.ParentId
				INNER JOIN bodb02.dbo.Site s WITH(NOLOCK)
				ON s.Site = p.PartyName OR s.Site = p.BranchName

			WHERE (@BopingControl 		= 1 AND g.PartyName = 'Boping Licensees')
				OR (@OneWorksControl 	= 1 AND g.PartyName = 'ONEWorks Licensees')
			
			-- Include Testing Licensee 
			UNION ALL
			SELECT 'ONEWorks Licensees' 	AS SiteControl
				, 37 AS siteid
				, 'spondemo' AS SiteName
		)
		INSERT INTO @tblSite
		SELECT ls.SiteControl
			, ls.siteid
			, ls.SiteName
		FROM CTE_LicenseeSite ls
			INNER JOIN [bodb_licensee].[dbo].[Licensees] lc WITH(NOLOCK) 
			ON ls.SiteName = lc.LicenseeName
			INNER JOIN [bodb_licensee].[dbo].[LicenseeProduct3rd] ld WITH(NOLOCK) 
			ON lc.LicenseeID = ld.LicenseeID
			INNER JOIN [bodb_licensee].[dbo].[Product3rd] p WITH(NOLOCK) 
			ON ld.ProductID = p.ProductID
			INNER JOIN @tblProduct tp 
			ON p.ProductName = tp.ProductName		
			
	
		DROP TABLE #LA_PartyList
	
	END
	
	IF(@CreditControl = 1)
	BEGIN
		INSERT INTO @tblSite
		SELECT 'Credit Licensees' AS SiteControl
			, s.siteid
			, s.[site] AS SiteName
		FROM bodb02.dbo.[Site] s WITH (NOLOCK)
		WHERE IsActive 			= 1
			AND IsLicensee 		= 0
			AND IsDeposit 		= 0
	END
		
	-- Output SiteControl
	SELECT 
		SiteControl
		,SiteId
		,SiteName
	FROM @tblSite
	
	-- Output ProductControl
	SELECT 
		ProductId
		,ProductName
	FROM @tblProduct
	
	RETURN;
END

GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_SelPermission] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_SelPermission] TO [vnteam]
GO
