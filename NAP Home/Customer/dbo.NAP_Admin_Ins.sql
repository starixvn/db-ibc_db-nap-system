USE [CustDB]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Admin_Ins]    Script Date: 8/1/2014 10:17:45 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.NAP_Admin_Ins    Script Date: 2/19/2014 11:08:51 AM ******/
/****** Object:  Stored Procedure dbo.NAP_Admin_Ins    Script Date: 12/9/2013 12:53:47 PM ******/
ALTER PROCEDURE [dbo].[NAP_Admin_Ins]
	@FirstName NVARCHAR (50) = NULL OUTPUT, 
	@LastName NVARCHAR (50) = NULL OUTPUT,
	@Email	NVARCHAR (50) = NULL OUTPUT, 
	@UserName VARCHAR (30) OUTPUT, 
	@UserPwd VARCHAR (40)='', 
	@CustID INT OUTPUT, 
	@CurrentUserId INT, 
	@ErrCode INT=0 OUTPUT, 
	@ErrMsg NVARCHAR (200)='' OUTPUT
AS
SET NOCOUNT ON;
/*
	Created: 
	Task : Add new admin account in NAP Admin system.
	DB: DBTRANS.bodb02
	Original:

	Revisions:
	• 20140219@Kos: Sync user with AdminSiteUser
	Param's Explanation:
	• @ErrCode:
		= 0: Insert successfully.
		> 0: Specific Error.
  
	• @ErrMsg: Error description.
*/
DECLARE @roleId TINYINT
SELECT	@roleId	= 6
	
INSERT  INTO customer (username, userpwd, roleid, firstname, lastname, email, creator)
VALUES               (@username, @userpwd, @roleId, @firstname, @lastname, @Email, @CurrentUserId)

SELECT @CustID = @@IDENTITY

IF @@ERROR <> 0
BEGIN
	SELECT @ErrMsg = N'Create new user failed.',
		@ErrCode = 103
		
	-- ROLLBACK MANUALLY
	DELETE FROM Customer WITH (ROWLOCK) WHERE custId = @CustID
		
	RETURN
END

INSERT INTO dbo.custinfo (username, [custid], [currency], [MaxPerMatch], [MaxPerMatch2], [MaxPerMatch3], [MaxPerMatch5], [MaxPerMatch8], [MaxPerMatch10], [MaxPerMatch11], [MaxPerMatch12], [MaxPerMatch99], [Maxpermatch151], [maxpermatch201], [MaxPerMatch161], [MaxPerMatch99MP], [MaxPerBall161], [MaxPerMatch151_OT], [roleid], [mrecommend], [recommend], [dangercust], [autosuspend], [reject], [credit], [MatchLimit], [VirtualMultiplier], [DisableHorseRacing], [DisableFinancial], [DisableCasino], [DisableOutright], [DisableOpenTote], [DisableBingo], [DisableNumber], [SyncCasino], [danger], [danger2], [danger3], [Enabled], [closed])
VALUES                   (@username, @custid, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, @roleid, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0);

IF @@ERROR <> 0
    BEGIN
        SELECT @ErrMsg = N'Create new user failed.',
		@ErrCode = 103
		
		-- ROLLBACK MANUALLY
		DELETE FROM Customer WITH (ROWLOCK) WHERE custId = @CustID
		DELETE FROM custinfo WITH (ROWLOCK) WHERE custId = @CustID
		
        RETURN        
    END

BEGIN TRY
	EXEC DBPRO.bodb02.dbo.Dot_Admin_Add_AdminSiteUser @CustID, @username, @userpwd, @CurrentUserId
END TRY
BEGIN CATCH
	SELECT 
		@ErrMsg = N'Create new user failed.',
		@ErrCode = 104
	
	DELETE FROM Customer WITH (ROWLOCK,UPDLOCK) WHERE custid = @CustID
	DELETE FROM custInfo WITH (ROWLOCK,UPDLOCK) WHERE custid = @CustID

	RETURN
END catch
