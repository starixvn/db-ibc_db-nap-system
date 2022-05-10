/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_Admin_Ins]
	@FirstName		NVARCHAR (50)	= NULL OUTPUT,
	@LastName		NVARCHAR (50)	= NULL OUTPUT,
	@Email			NVARCHAR (50)	= NULL OUTPUT,
	@UserName		VARCHAR (30) OUTPUT,
	@UserPwd		VARCHAR (40)	= '',
	@CustId			INT OUTPUT, 
	@CurrentUserId	INT, 
	@ErrCode		INT				= 0 OUTPUT,
	@ErrMsg			NVARCHAR (200)	= '' OUTPUT
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
	
	INSERT INTO dbo.Customer (username, userpwd, roleid, firstname, lastname, email, creator)
	VALUES (@UserName, @userpwd, @roleId, @firstname, @lastname, @Email, @CurrentUserId)

	SELECT @CustID = @@IDENTITY

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrMsg = N'Create new user failed.',
			@ErrCode = 103
		
		-- ROLLBACK MANUALLY
		DELETE FROM dbo.Customer WITH (ROWLOCK) WHERE custId = @CustId

		RETURN
	END

	INSERT INTO dbo.custinfo (username, [custid], [currency], [MaxPerMatch], [MaxPerMatch2], [MaxPerMatch3], [MaxPerMatch5], [MaxPerMatch8], [MaxPerMatch10], [MaxPerMatch11], [MaxPerMatch99], [MaxPerMatch161], [MaxPerMatch99MP], [MaxPerBall161], [roleid], [mrecommend], [recommend], [dangercust], [autosuspend], [reject], [credit], [MatchLimit], [VirtualMultiplier], [DisableOutright], [DisableNumber], [danger], [danger2], [danger3], [Enabled], [closed])
	VALUES (@UserName, @CustId, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, @roleid, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0);

	IF @@ERROR <> 0
		BEGIN
			SELECT @ErrMsg = N'Create new user failed.',
				@ErrCode = 103
		
			-- ROLLBACK MANUALLY
			DELETE FROM dbo.Customer WITH (ROWLOCK) WHERE custId = @CustID
			DELETE FROM dbo.custInfo WITH (ROWLOCK) WHERE custId = @CustID

			RETURN
		END

	BEGIN TRY
		EXEC DBPRO.bodb02.dbo.Dot_Admin_Add_AdminSiteUser @CustId, @UserName, @userpwd, @CurrentUserId
	END TRY
	BEGIN CATCH
		SELECT
			@ErrMsg = N'Create new user failed.',
			@ErrCode = 104
	
		DELETE FROM dbo.Customer WITH (ROWLOCK,UPDLOCK) WHERE custid = @CustId
		DELETE FROM dbo.custInfo WITH (ROWLOCK,UPDLOCK) WHERE custid = @CustId

		RETURN
	END CATCH
END
GO

GRANT EXECUTE ON NAP_Admin_Ins TO bodbAdminNet
GO