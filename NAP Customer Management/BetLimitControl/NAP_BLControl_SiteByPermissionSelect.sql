/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_SiteByPermissionSelect] 
	@UserID INT = 0
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - select Site for dropdown
	DB: DBACC-bodb02
	Original:

	Revisions:  
	- 20200602@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:

	Example: 
	EXEC NAP_BLControl_SiteByPermissionSelect @UserID = 8

	*/
BEGIN

	DECLARE @HasCN88_Permission BIT = 0,
		@HasCredit_Permission BIT = 0,
		@HasLicensee_Permission BIT = 0

	DECLARE @ErrorCode INT = 0 

	EXEC DBCUST.NAP_UserControl.dbo.NAP_User_CheckPermission 
			@UserId=@userid,
			@SiteKey='CustomerManagement',
			@FunctionKey='BLC_CN88Site',
			@Policy=1,
			@ErrCode=@ErrorCode OUTPUT

	IF @ErrorCode = 0 SET @HasCN88_Permission = 1

	SET @ErrorCode = 0
	EXEC DBCUST.NAP_UserControl.dbo.NAP_User_CheckPermission 
			@UserId=@userid,
			@SiteKey='CustomerManagement',
			@FunctionKey='BLC_Credit',
			@Policy=1,
			@ErrCode=@ErrorCode OUTPUT

	IF @ErrorCode = 0 SET @HasCredit_Permission = 1

	SET @ErrorCode = 0
	EXEC DBCUST.NAP_UserControl.dbo.NAP_User_CheckPermission 
			@UserId=@userid,
			@SiteKey='CustomerManagement',
			@FunctionKey='BLC_LicenseeSite',
			@Policy=1,
			@ErrCode=@ErrorCode OUTPUT

	IF @ErrorCode = 0 SET @HasLicensee_Permission = 1

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


