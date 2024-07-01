/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_GlobalStakeLevelGroup_CurrencySel] 
	-- Add the parameters for the stored procedure here
	 @IsCredit BIT=1 -- 1 : Credit, 0 :Deposit
AS
/*
	Created: 20230914@Tacy
	Task : 3rd Products - Simplify RNG Games bet limit setting
	DB: DBACC/bodb02

	Revisions:
		- 20230914@Tacy: Create SP [Redmine: #194332]
		- 20240624@Tacy: Implement more function [Redmine: #196256]
		
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #Exchange (ExchangeID INT PRIMARY KEY, 
							Currency NVARCHAR(50),
							CreditGroupID TINYINT,
							LicenseeGroupID TINYINT)

	INSERT INTO #Exchange (ExchangeID, Currency, CreditGroupID, LicenseeGroupID)
	SELECT 
		 ExchangeID, Currency, CreditGroupID, LicenseeGroupID
	FROM Exchange  WITH(NOLOCK)
	WHERE IsActive = 1 AND ((@IsCredit = 1 AND OfferSite IN (0,1)) OR (@IsCredit = 0 AND OfferSite IN (0,2)))

	IF @IsCredit=1
	BEGIN
		SELECT e.ExchangeID, e.Currency
		FROM #Exchange e
		CROSS APPLY (SELECT TOP 1 1 AS VAL 
					 FROM ProductStakeLevelGroup P WITH (NOLOCK) 
					 WHERE e.CreditGroupID=p.CreditGroupID) p
		ORDER BY e.Currency
	END
	ELSE 
	BEGIN
		SELECT e.ExchangeID, e.Currency
		FROM #Exchange e
		CROSS APPLY (SELECT TOP 1 1 AS VAL 
					 FROM Dep_ProductStakeLevelGroup P WITH (NOLOCK) 
					 WHERE e.LicenseeGroupID=p.LicenseeGroupID) p
		ORDER BY e.Currency
	END
END
GO
