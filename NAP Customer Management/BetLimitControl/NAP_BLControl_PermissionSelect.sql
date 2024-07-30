/*<info serverAlias="DBPOL-NAP_UserControl" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_PermissionSelect] 
	@UserID		INT,
	@HasCN88_Permission		BIT = 0 OUTPUT,
	@HasCredit_Permission	BIT = 0 OUTPUT,
	@HasLicensee_Permission BIT = 0 OUTPUT,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(200) = '' OUTPUT
AS
/*
	Created: 20240726@Tacy
	Task : Bet Limit Control - select sub-permission
	DB: DBPOL-NAP_UserControl
	Original:

	Revisions:  
	- 20240726@Tacy: Create New SP  [RedmineID: #208402]

	Parameter explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SiteKey NVARCHAR(50) = 'CustomerManagement'

	EXEC dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey=@SiteKey,
		@FunctionKey='BetLimitControl',
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		GOTO EndStep;

	BEGIN
		EXEC dbo.NAP_User_CheckPermission 
				@UserId=@userid,
				@SiteKey=@SiteKey,
				@FunctionKey='BLC_CN88Site',
				@Policy=1,
				@ErrCode=@ErrorCode OUTPUT

		IF @ErrorCode = 0 SET @HasCN88_Permission = 1

		SET @ErrorCode = 0
		EXEC dbo.NAP_User_CheckPermission 
				@UserId=@userid,
				@SiteKey=@SiteKey,
				@FunctionKey='BLC_Credit',
				@Policy=1,
				@ErrCode=@ErrorCode OUTPUT

		IF @ErrorCode = 0 SET @HasCredit_Permission = 1

		SET @ErrorCode = 0
		EXEC dbo.NAP_User_CheckPermission 
				@UserId=@userid,
				@SiteKey=@SiteKey,
				@FunctionKey='BLC_LicenseeSite',
				@Policy=1,
				@ErrCode=@ErrorCode OUTPUT

		IF @ErrorCode = 0 SET @HasLicensee_Permission = 1
	END

	EndStep:
		RETURN
END
GO