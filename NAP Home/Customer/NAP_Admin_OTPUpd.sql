/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_OTPUpd]
	@CustId		INT	,	
	@SecretKey	NVARCHAR (50) = Null,
	@System		VARCHAR (10) = 'NAP',
	@IgnoreOTP  BIT,
	@Modifier 	INT,
	@LoginIP	VARCHAR(30)		= '',
	@ErrCode	INT				= 0			OUTPUT,
	@ErrMsg		NVARCHAR(1000)	= ''		OUTPUT 
AS

/*
	Created: 20220517@Winfred
	Task :	NAP OTP Login requried for VPN's users
	DB: DBPOL/NAP_UserControl
	Original:

	Revisions:
	    - 20220517@Winfred: Update OTP Login requried for VPN's users [redmine:170994]
	    
	Param's Explanation:
	• @CustId :
		= custid from bodb02.dbo.Customer and bodb02.dbo.custinfo
	• @ErrCode:
		= 0: Insert successfully.
		> 0: Specific Error.
	  
	• @ErrMsg: Error description.

	*** WRITE LOG template:
	Main	:	<root><xml path="r" />
					<row item="CustId" alias="u" />
					<row item="SecretKey" alias="sk" />
					<row item="System" alias="s" />
					<row item="IgnoreOTP" alias="i" />
					<row item="Modifier" alias="m" />
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
	
	-- Update OTP admin

	Update AdminOTP with (ROWLOCK, UPDLOCK)
	SET SecretKey = @SecretKey, IgnoreOTP = @IgnoreOTP, Modifier = @Modifier, ModifiedDate = GETDATE()
	WHERE CustID = @CustID AND System = @System

	IF @@ERROR <> 0
		BEGIN
			SELECT @ErrMsg = N'Update new user failed.',
				@ErrCode = 104
			RETURN
		END

	-- Write log
	SET @xml = (
		SELECT @CustId			AS '@ui'
				,@System		AS '@s'
				,@SecretKey		AS '@sk'
				,@IgnoreOTP		AS '@i'
				,@Modifier		AS '@m'
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC dbo.NAP_RunSP_WriteLog 
	@UserId			= @Modifier,
	@SPName			= 'NAP_Admin_OTPUpd',
	@ObjectId		= @CustId,
	@ObjectTypeId	= 1,					-- Object type : User
	@IP				= @LoginIP,
	@Date			= @startRun,
	@Data			= @logSPData,
	@OldData		= @logSPDataOld,
	@Duration		= @Duration

END

