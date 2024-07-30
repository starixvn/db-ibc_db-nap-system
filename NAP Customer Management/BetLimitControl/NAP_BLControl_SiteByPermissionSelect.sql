/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_SiteByPermissionSelect] 
	@HasCN88_Permission BIT = 0,
	@HasCredit_Permission BIT = 0,
	@HasLicensee_Permission BIT = 0
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - select Site for dropdown
	DB: DBACC-bodb02
	Original:

	Revisions:  
	- 20200602@Eden: Create New SP  [RedmineID: #132736]
	- 20240725@Tacy: Remove linked-server/cross-db on NAP_UserControl [redmineID: #208402]

	Parameter explanation:

	Example: 
	EXEC NAP_BLControl_SiteByPermissionSelect @UserID = 8

	*/
BEGIN
	SET NOCOUNT ON;

	SELECT SiteID,Site
	FROM dbo.[Site] WITH(NOLOCK)
	WHERE Site ='CN88' AND @HasCN88_Permission = 1
	UNION ALL
	SELECT SiteID,Site
	FROM dbo.[Site] WITH(NOLOCK)
	WHERE Site <> 'CN88' AND isLicensee = 1 AND @HasLicensee_Permission = 1
	UNION ALL
	SELECT SiteID,Site
	FROM dbo.[Site] WITH(NOLOCK)
	WHERE Site <> 'CN88' AND isLicensee = 0 AND @HasCredit_Permission = 1
	ORDER BY Site
END
GO


