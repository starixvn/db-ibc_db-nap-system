CREATE PROCEDURE [dbo].[NAP_Cust_UpdatePassword]
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
	DB: DBTRANS.bodb02
	Original:

	Revisions:
	    
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

	DECLARE @pwdExpiry DATETIME

	SELECT @pwdExpiry = DATEADD(DD, 30, GETDATE())
	
	-- Update password
	UPDATE dbo.Customer WITH (ROWLOCK, UPDLOCK)
	SET	
		userpwd = @UserPwd,
		pwdexpiry = @PwdExpiry 
	WHERE custid = @CustId
		
	IF @@ERROR <> 0
		BEGIN
			SELECT 
				@ErrCode = 103,
				@ErrMsg = N'Update fail UserId ' + COALESCE(CAST(@CustId AS VARCHAR(10)), SPACE(1)) 
			RETURN
		END	
	
	-- Write log after update
	SET @xml = (
		SELECT cu.custid		AS '@ui'
				,cu.userpwd		AS '@p'				
		FROM dbo.Customer AS cu WITH (NOLOCK)
		WHERE cu.custid = @CustId
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   

	EXEC db054.bodb_NAPLOG.dbo.NAP_LogRunSp_Insert
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