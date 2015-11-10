USE [bodb_licensee]
GO
ALTER PROCEDURE [dbo].[NAP_PayoutTrans_SelLicenseeSite]
(
	@AdminId			INT		= 0
	, @PayoutControl	INT	 	= 14
)
AS
/*
Created: 20151012@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBEXT.bodb_licensee
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
	
	
	DECLARE @tblProduct			TABLE
	(
		ProductId				SMALLINT
		,ProductName			VARCHAR(100)
	)
	CREATE TABLE #LA_PartyList (PartyId int, PartyName varchar(100), BranchName varchar(100), ParentId int)
	
	SELECT @BopingControl 	= (2 & @PayoutControl)
		, @OneWorksControl	= (4 & @PayoutControl)

	-- SELECT product control
	INSERT INTO @tblProduct	
	SELECT DISTINCT 
		s.sporttype
		, s.SportName
	FROM bodb02.dbo.Sports s WITH(NOLOCK)
	WHERE ((@BopingControl 	= 1 OR  @OneWorksControl = 1) AND s.sporttype IN (205)) --Microgaming RNG Casino
	
	
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
			INNER JOIN bodb02.dbo.Site s
			ON s.Site = p.PartyName OR s.Site = p.BranchName

		WHERE (@BopingControl 		= 1 AND g.PartyName = 'Boping Licensees')
			OR (@OneWorksControl 	= 1 AND g.PartyName = 'ONEWorks Licensees')
	)
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
	
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].NAP_PayoutTrans_SelLicenseeSite TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].NAP_PayoutTrans_SelLicenseeSite TO [vnteam]
GO
exec [dbo].NAP_PayoutTrans_SelLicenseeSite