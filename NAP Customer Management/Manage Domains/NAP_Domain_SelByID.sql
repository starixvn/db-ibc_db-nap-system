/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROC [dbo].[NAP_Domain_SelByID]
	 @DomainID	INT
AS
/*
	Created: 20231013@Tacy
	Task: Get domain info by domainID
	DB: DBACC-bodb02
	
	Revisions:
		- 20231013@Tacy: Create SP [RedmineID: #194024]
*/
BEGIN
	SET NOCOUNT ON;

	IF ISNULL(@DomainID,0)=0	RETURN

	SELECT d.DomainID, d.Domain, d.System, d.site, d.BrandName
		, d.Status
		, d.RestrictedCountries
		, d.Remark
		, d.ExpiredDate
		, d.LastUpdateTime
	FROM DomainManagement d WITH (NOLOCK)
	WHERE DomainID=@DomainID AND isDeleted=0
END
GO