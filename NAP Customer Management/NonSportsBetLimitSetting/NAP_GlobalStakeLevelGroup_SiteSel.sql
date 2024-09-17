/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_GlobalStakeLevelGroup_SiteSel] 
	-- Add the parameters for the stored procedure here
	@IsCredit	BIT=0, -- 1 : Credit, 0 :Deposit
	@IsGetAll	BIT=0
AS
/*
	Created: 20230914@Tacy
	Task : 3rd Products - Simplify RNG Games bet limit setting
	DB: DBACC/bodb02

	Revisions:
		- 20230914@Tacy: Create SP [Redmine: #194332]
		- 20240925@Tacy: Implement more function [Redmine: #196256]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #Site (SiteID INT PRIMARY KEY, 
						Site NVARCHAR(50))

	INSERT INTO #Site (SiteID, Site)
	SELECT siteid, site
	FROM Site  WITH(NOLOCK)
	WHERE IsActive = 1 AND ((@IsCredit = 1 AND isDeposit=0) OR (@IsCredit = 0 AND isDeposit=1))
		AND site<>'CN88'

	;WITH TMP AS (
		SELECT 0 AS SiteID, 'All Sites' AS Site
		UNION ALL
		SELECT s.SiteID, s.Site
		FROM #Site s
		OUTER APPLY (SELECT TOP 1 1 AS VAL 
						FROM Dep_ProductStakeLevelGroup P WITH (NOLOCK) 
						WHERE s.SiteID=p.SiteID
						AND p.isDeleted=0) p
		WHERE @IsGetAll=1
			OR (@IsGetAll=0 AND p.VAL IS NOT NULL)
	)
	SELECT SiteID, Site 
	FROM TMP
	ORDER BY Site	
END
GO