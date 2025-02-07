/*<info serverAlias="DBPOL-NAP_UserControl" executers="wsv_nap" viewers="vnteam" isFunction="0" isNested="0"></info>*/
Create PROCEDURE [dbo].[NAP_Cust_Insert]
	@CustId			INT,	
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
	DB: DBPOL/NAP_UserControl
	Original:

	Revisions:
		- 20150606@Kathy: Change link server DBTXN.CustDB to DBCust.CustDB [Redmine:#36216]
	    - 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
		- 20220517@Winfred: Insert new OTP Login requried for VPN's users [redmine:170994]
	    - 20240704@Louisa: Scaleout DBCUST [Redmine:#199915]
		- 20250206@Virgil: Hotfix cannot create new user [Redmine: #217493]

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

	-- Create new NAP user
	EXEC [dbo].[NAP_User_Insert] 
		@UserId			= @CustId,
		@Username		= @Username,
		@GroupId		= @GroupId,
		@CreatedBy		= @CurrentUserId,
		@CreatedDate	= @LogDate,
		@CurrentUserId	= @CurrentUserId,
		@CurrentSiteId	= @CurrentSiteId,
		@LogDate		= @LogDate,
		@LoginIP		= @LoginIP,
		@Language		= @Language,
		@ErrCode		= @ErrCode OUTPUT,
		@ErrMsg			= @ErrMsg OUTPUT
	IF @ErrCode > 0
	BEGIN
		SELECT @ErrCode = @ErrCode, @ErrMsg = @ErrMsg
		RETURN	
	END

	-- Create new NAP OTP admin
	EXEC [dbo].[NAP_Admin_OTPIns] 
		@CustId			= @CustId,
		@System			= 'NAP',
		@UserId			= @CurrentUserId,
		@ErrCode		= @ErrCode OUTPUT,
		@ErrMsg			= @ErrMsg OUTPUT
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
		FROM dbo.NAP_Users AS u WITH(NOLOCK)
			INNER JOIN dbo.NAP_Groups AS g WITH(NOLOCK) ON u.GroupId = g.GroupId
		WHERE u.userid = @CustId 
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC dbo.NAP_RunSP_WriteLog 
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
