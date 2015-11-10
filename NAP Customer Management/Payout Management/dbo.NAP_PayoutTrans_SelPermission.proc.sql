USE [bodb02]
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
DB: DBAGE.bodb02
Original:
Revisions:
	- 20151012@bobby.nguyen: Initial
	
Param's Explanation:
	- @AdminId: Id of admin user login
	- @PayoutControl: bitwise operator bits[1:Boping-2:OneWorks-3:Credit]
	
	
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
		, s.SportName
	FROM dbo.Sports s WITH(NOLOCK)
	WHERE ((@BopingControl 	= 1 OR  @OneWorksControl = 1) AND s.sporttype IN (205)) --Microgaming RNG Casino
		OR (@CreditControl 	= 1 AND s.sporttype IN (204)) --Colossus Bets
		
	
	IF(@BopingControl 		= 1
		OR @OneWorksControl = 1
	)
	BEGIN
		
		INSERT INTO @tblSite
		EXEC [DBLIC].[bodb_licensee].[dbo].[NAP_PayoutTrans_SelLicenseeSite]
		@AdminId 			= @AdminId
		, @PayoutControl 	= @PayoutControl
	
		/*
		CREATE TABLE #LA_PartyList (PartyId int, PartyName varchar(100), BranchName varchar(100), ParentId int)
		
		INSERT INTO #LA_PartyList
		EXEC [DBLIC].bodb_licensee.dbo.LA_PartyListSel
				
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
				INNER JOIN dbo.Site s
				ON s.Site = p.PartyName OR s.Site = p.BranchName

			WHERE (@BopingControl 		= 1 AND g.PartyName = 'Boping Licensees')
				OR (@OneWorksControl 	= 1 AND g.PartyName = 'ONEWorks Licensees')
		)
		INSERT INTO @tblSite
		SELECT ls.SiteControl
			, ls.siteid
			, ls.SiteName
		FROM CTE_LicenseeSite ls
			INNER JOIN [bodb_licensee].[dbo].[Licensees] lc WITH(NOLOCK) 
			ON ts.SiteName = lc.LicenseeName
			INNER JOIN [bodb_licensee].[dbo].[LicenseeProduct3rd] ld WITH(NOLOCK) 
			ON lc.LicenseeID = ld.LicenseeID
			INNER JOIN [bodb_licensee].[dbo].[Product3rd] p WITH(NOLOCK) 
			ON ld.ProductID = p.ProductID
			INNER JOIN @tblProduct tp 
			ON p.ProductName = tp.ProductName		
		*/
	END
	
	IF(@CreditControl = 1)
	BEGIN
		INSERT INTO @tblSite
		SELECT 'Credit Licensees' AS SiteControl
			, s.siteid
			, s.[site] AS SiteName
		FROM dbo.[Site] s WITH (NOLOCK)
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
EXEC [dbo].[NAP_PayoutTrans_SelPermission]