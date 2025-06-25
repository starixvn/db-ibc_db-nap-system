/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROC [dbo].[NAP_Domain_SelByID]
	 @DomainID	VARCHAR(MAX)
AS
/*
	Created: 20231013@Tacy
	Task: Get domain info by domainID
	DB: DBACC-bodb02
	
	Revisions:
		- 20231013@Tacy: Create SP [RedmineID: #194024]
		- 20250701@Johnson: offer Agency Cash Service [RedmineID: #231219]
*/
BEGIN
	SET NOCOUNT ON;

	IF ISNULL(@DomainID,'')=''	RETURN

	SELECT d.DomainID, d.Domain, d.System, d.site, d.BrandName
		, d.Status
		, d.OfferType
		, d.RestrictedCountries
		, d.Remark
		, d.ExpiredDate
		, d.LastUpdateTime
	FROM DomainManagement d WITH (NOLOCK)
	WHERE DomainID IN (SELECT value FROM STRING_SPLIT(@DomainID, ','))
	 	AND isDeleted=0
END
GO