/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Cust_UpdatePassword]
	@CustId			INT,
	@UserPwd		NVARCHAR (50),
	@CurrentUserId	INT,
    @CurrentSiteId	INT,
	@LogDate		DATETIME,
	@LoginIP		VARCHAR(30)		=   '',
	@Language		VARCHAR(20)		=   'en-us',
	@ErrCode		INT				=   0			OUTPUT,
	@ErrMsg			NVARCHAR(1000)	=   ''			OUTPUT
AS

/*
	Created: 20120709@Edward
	Task : Update user password from bodb02.dbo.Customer
	DB: DBCUST/CUSTDB
	Original:

	Revisions:
		- 20140219@Kos:	Sync password with AdminSiteTable
	    - 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	    - 20241209@Johnson: Apply In-house replication for Credit Setting [RedmineID: #212684]
	Param's Explanation:
	• @CustId :
		= custid from bodb02.dbo.Customer and bodb02.dbo.custinfo
		= UserId from bodb_NAP.Users
	• @ErrCode:
	• @ErrMsg: Error description.
	• Main	:	<root><xml path="r" />					
					<row item="UserId" alias="ui" />
					<row item="Password" alias="p" />					
				</root>
*/

BEGIN
	SET NOCOUNT ON    
   
	-- For write log
    DECLARE 
		@startRun		DATETIME,
		@endRun			DATETIME,
		@duration		INT,
		@logSPData		VARCHAR(5000),
		@logSPDataOld	VARCHAR(5000),	        
		@xml			XML

	SET @startRun = GETDATE()
	
	-- Write log before update
	SET @xml = (
		SELECT cu.custid		AS '@ui'
				,cu.userpwd	AS '@p'				
		FROM dbo.Customer AS cu WITH (NOLOCK)
		WHERE cu.custid = @CustId
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')		

	DECLARE 
		@pwdExpiry		DATETIME,
		@oldUserPwd		VARCHAR(40),
		@oldPwdExpiry	DATETIME,
		@roleId			INT

	SELECT @pwdExpiry = DATEADD(DD, 30, GETDATE())

	SELECT 
		@oldUserPwd = userpwd, 
		@oldPwdExpiry = pwdexpiry,
		@roleID = roleid
	FROM dbo.Customer WITH (NOLOCK)
	WHERE custid = @CustId 
	
	-- Update password
	UPDATE dbo.Customer WITH (ROWLOCK, UPDLOCK)
	SET	
		userpwd = @UserPwd,
		pwdexpiry = @PwdExpiry,
		RepUpdateTime = dbo.f_GetDateTime2()	
	WHERE custid = @CustId
		
	IF @@ERROR <> 0
		BEGIN
			SELECT 
				@ErrCode = 103,
				@ErrMsg = N'Update fail UserId ' + COALESCE(CAST(@CustId AS VARCHAR(10)), SPACE(1)) 
			RETURN
		END	

	BEGIN TRY 			
		IF @RoleID > 4
			EXEC DBPRO.bodb02.dbo.DOT_Admin_ChangeAdminUserPassword @CustId, @UserPwd
	END TRY
	BEGIN CATCH
		UPDATE dbo.Customer WITH (ROWLOCK, UPDLOCK)
		SET 
			userpwd = @oldUserPwd, 
			pwdexpiry = @oldPwdExpiry,
			RepUpdateTime = dbo.f_GetDateTime2()
		WHERE custid = @CustId

 		SELECT 
			@ErrCode = 104,
			@ErrMsg = 'Update password does not successfully.'
 		RETURN
	END CATCH
	
	-- Write log after update
	SET @xml = (
		SELECT 
			cu.custid	AS '@ui',
			cu.userpwd	AS '@p'				
		FROM dbo.Customer AS cu WITH (NOLOCK)
		WHERE cu.custid = @CustId
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
	
	EXEC NAP_UserControl.dbo.NAP_RunSP_WriteLog
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Cust_UpdatePassword',
	@ObjectId		= @CustId,
	@ObjectTypeId	= 1,					-- Object type : User
	@Language		= @Language,
	@SiteID			= @CurrentSiteId,
	@IP				= @LoginIP,
	@Date			= @LogDate,
	@Data			= @logSPData,
	@OldData		= @logSPDataOld,
	@Duration		= @Duration
END
GO
