ALTER PROCEDURE [dbo].[NAP_Cust_Insert]
	@CustId			INT							OUTPUT,	
	@Username		VARCHAR (30),
	@UserPwd		VARCHAR (40)	= '',
	@FirstName		NVARCHAR (50)	= NULL,
	@LastName		NVARCHAR (50)	= NULL,
	@Email			NVARCHAR (50)	= NULL,	
	@GroupId		SMALLINT,
	@CurrentUserId	INT,
    @CurrentSiteId	TINYINT,
	@LogDate		DATETIME,
	@LoginIP		VARCHAR(30)		= '',
	@Language		VARCHAR(10)		= 'en-us',
	@ErrCode		INT				= 0			OUTPUT,
	@ErrMsg			NVARCHAR(1000)	= ''		OUTPUT 
AS

/*
	Created: 20120709@Edward
	Task :	Insert new user to custinfo and customer of bodb02 with roleid = 6
			and add to User of bodb_NAP
	DB: DB052.bodb_NAP
	Original:

	Revisions:
	    
	Param's Explanation:
	• @CustId :
		= custid from bodb02.dbo.Customer and bodb02.dbo.custinfo
		= UserId from bodb_NAP.Users
	• @ErrCode:
		= 0: Insert successfully.
		> 0: Specific Error.
	  
	• @ErrMsg: Error description.

	*** WRITE LOG template:
	Main	:	<root><xml path="r" />
					<row item="Username" alias="u" />
					<row item="UserId" alias="ui" />
					<row item="GroupId" alias="gi" />
					<row item="GroupName" alias="g" />
					<row item="FirstName" alias="f" />
					<row item="LastName" alias="l" />
					<row item="Email" alias="e" />
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

	-- Time start
	SET @startRun = GETDATE()
	
	-- Check role of current user of bodb02.dbo.Customer 
	DECLARE @isAllow TINYINT

	SELECT @isAllow = roleid 
	FROM bodb02.dbo.Customer WITH (NOLOCK) 
	WHERE custid = @CurrentUserId
	
	-- Check duplicate username
	IF EXISTS (	SELECT 1
				FROM   bodb02.dbo.Customer WITH (NOLOCK)
				WHERE  username = @Username	)
		BEGIN
			SELECT 
				@ErrCode = 102,
				@ErrMsg = N'This username is not available.'			
			RETURN
		END

	-- create new user in customer/custinfo tables
	EXEC	[DBTRANS].[bodb02].[dbo].[NAP_Admin_Ins]
			@FirstName = @FirstName OUTPUT,
			@LastName = @LastName OUTPUT,
			@Email = @Email OUTPUT,
			@UserName = @UserName OUTPUT,
			@UserPwd = @UserPwd,
			@CustID = @CustID OUTPUT,
			@CurrentUserId = @CurrentUserId,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT
	IF @ErrCode > 0
	BEGIN
		SELECT @ErrCode = @ErrCode, @ErrMsg = @ErrMsg
		RETURN	
	END
	

	-- Create new NAP user
	EXEC [dbo].[NAP_User_Insert] 
		@UserId = @CustId,
		@Username = @Username,
		@GroupId = @GroupId,
		@CreatedBy = @CurrentUserId,
		@CreatedDate = @LogDate,
		@CurrentUserId = @CurrentUserId,
		@CurrentSiteId = @CurrentSiteId,
		@LogDate = @LogDate,
		@LoginIP = @LoginIP,
		@Language = @Language,
		@ErrCode = @ErrCode OUTPUT,
		@ErrMsg = @ErrMsg OUTPUT
	IF @ErrCode > 0
	BEGIN
		SELECT @ErrCode = @ErrCode, @ErrMsg = @ErrMsg
		RETURN	
	END

	-- Write log
	SET @xml = (
		SELECT @CustId			AS '@ui'
				,@Username		AS '@u'
				,@GroupId		AS '@gi'
				,g.GroupName	AS '@g'
				,@FirstName		AS '@f'
				,@LastName		AS '@l'
				,@Email			AS '@e'
		FROM Users AS u WITH(NOLOCK)
		INNER JOIN Groups AS g WITH(NOLOCK) ON u.GroupId = g.GroupId
		WHERE u.userid = @CustId 
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Cust_Insert',
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
GRANT EXECUTE ON [dbo].[NAP_Cust_Insert] TO [bodbAdminNet]