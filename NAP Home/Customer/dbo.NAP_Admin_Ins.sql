/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Ins]
(
	@FirstName		NVARCHAR (50)	= NULL,
	@LastName		NVARCHAR (50)	= NULL,
	@Email			NVARCHAR (50)	= NULL,
	@UserName		VARCHAR (30),
	@UserPwd		VARCHAR (40)	= '',
	@CustId			INT, 
	@CurrentUserId	INT, 
	@ErrCode		INT				= 0 OUTPUT,
	@ErrMsg			NVARCHAR (200)	= '' OUTPUT
)
AS

/*
	Created: 
	Task : Add new admin account in NAP Admin system.
	DB: DBCUST.CustDB
	Original:

	Revisions:
		- 20140219@Kos: Sync user with AdminSiteUser
		- 20191016@Kos: Remove inactive products phase 2 [Redmine: #118699]
		- 20220110@Eden: Saba Casino use DCS Setting [RedmineID: #164280]
		- 20221013@Eden: Remove unused columns from Custinfo table [RedmineID: #179014]
		- 20221123@Elodie: Migrate NG and Keno to DCS structure [Redmine: #179711]
		- 20240704@Louisa: Scaleout DBCUST [Redmine:#199915]

	Param's Explanation:
	• @ErrCode:
		= 0: Insert successfully.
		> 0: Specific Error.
  
	• @ErrMsg: Error description.
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @roleId TINYINT
	SELECT	@roleId	= 6

	BEGIN TRY
		EXEC Acc_CustomerIns
			@FirstName	= @firstname
			,@LastName	= @lastname
			,@Email		= @Email
			,@UserName	= @UserName
			,@UserPwd	= @userpwd
			,@roleid	= @roleId
			,@CustID	= @CustId
			,@srecommend= 0
			,@creator	= @CurrentUserId
			,@ErrCode	= @ErrCode OUTPUT
			,@ErrMsg	= @ErrMsg OUTPUT
	
			IF ISNULL(@ErrCode,0) > 0
			BEGIN
				EXEC Acc_CustomerInsUserInfo_Rollback @CustID = @CustID
				RETURN;
			END

		INSERT INTO dbo.custinfo (username, [custid], [currency], [roleid], [srecommend], [mrecommend], [recommend], [dangercust], [autosuspend], [reject], [credit], [MatchLimit], [VirtualMultiplier], [DisableOutright], [danger], [danger2], [danger3], [Enabled], [closed])
		VALUES (@UserName, @CustId, NULL, @roleid, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0);
	END TRY
	BEGIN CATCH	
		SELECT
			@ErrMsg = N'Create new user failed.',
			@ErrCode = 104
	
		EXEC Acc_CustomerInsUserInfo_Rollback @CustID = @CustID

		RETURN
	END CATCH
END
GO