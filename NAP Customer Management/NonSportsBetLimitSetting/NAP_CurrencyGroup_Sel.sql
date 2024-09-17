/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_CurrencyGroup_Sel] 
	-- Add the parameters for the stored procedure here
	 @IsCredit BIT=1 -- 1 : Credit, 0 :Deposit
AS
/*
	Created: 20230914@Tacy
	Task : Nap CM - Non-sport Company Bet Limit Setting - Manage Currency Group
	DB: DBACC/bodb02

	Revisions:
		- 20230914@Tacy: Create SP [Redmine: #196256]
		
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	IF @IsCredit=1
	BEGIN
		SELECT ExchangeID, Currency, Code, CreditGroupID AS CurrencyGroupID
		FROM Exchange  WITH(NOLOCK)
		WHERE IsActive = 1 AND @IsCredit = 1 AND OfferSite IN (0,1)
			AND CreditGroupID IS NOT NULL
		ORDER BY CreditGroupID, Currency
	END
	ELSE 
	BEGIN
		SELECT ExchangeID, Currency, Code, LicenseeGroupID AS CurrencyGroupID
		FROM Exchange  WITH(NOLOCK)
		WHERE IsActive = 1 AND @IsCredit = 0 AND OfferSite IN (0,2)
			AND LicenseeGroupID IS NOT NULL
		ORDER BY LicenseeGroupID, Currency
	END
END
GO