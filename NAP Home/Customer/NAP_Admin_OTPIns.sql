/*<info serverAlias="DBPOL-NAP_UserControl" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_OTPIns]
	@CustId		INT	,	
	@System		VARCHAR (10) = 'NAP',
	@UserId		INT,
	@ErrCode	INT				= 0			OUTPUT,
	@ErrMsg		NVARCHAR(1000)	= ''		OUTPUT 
AS

/*
	Created: 20220517@Winfred
	Task :	NAP OTP Login requried for VPN's users
	DB: DBPOL/NAP_UserControl
	Original:

	Revisions:
	    - 20220517@Winfred: Insert new OTP Login requried for VPN's users [redmine:170994]
	    
	Param's Explanation:
	• @CustId :
		= custid from bodb02.dbo.Customer and bodb02.dbo.custinfo
	• @UserId :
		= UserId from Users insert
	• @ErrCode:
		= 0: Insert successfully.
		> 0: Specific Error.
	  
	• @ErrMsg: Error description.

	*** WRITE LOG template:
	Main	:	<root><xml path="r" />
					<row item="CustId" alias="u" />
					<row item="System" alias="s" />
					<row item="UserId" alias="ui" />
					<row item="LoginIP" alias="l" />
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
	
	-- Check starix user 
	IF NOT EXISTS(SELECT TOP 1 1 FROM CustDB.dbo.custInfo a  WITH(NOLOCK)
				WHERE a.roleid > 4 AND a.Enabled=1 AND a.username LIKE '%' + 'STARIX' + '%'
				AND a.custid = @CustID
				) OR EXISTS (SELECT TOP 1 1 FROM AdminOTP WITH(NOLOCK) WHERE custid = @CustID AND System = @System )
	BEGIN
		RETURN
	END

	-- create new user in OTP tables
	INSERT INTO AdminOTP(CustID,System,Modifier, ModifiedDate, Creator,CreatedDate)
	VALUES( @CustID, @System, NUll, NUll, @UserId, GETDATE())

	IF @@ERROR <> 0
		BEGIN
			SELECT @ErrMsg = N'Create new user failed.',
				@ErrCode = 103
			RETURN
		END

	-- Write log
	SET @xml = (
		SELECT @CustId			AS '@u'
				,@System		AS '@s'
				,@UserId		AS '@ui'
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	SET @endRun	= GETDATE()  
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)   
			
	EXEC dbo.NAP_RunSP_WriteLog 
	@UserId			= @UserId,
	@SPName			= 'NAP_Admin_OTPIns',
	@ObjectId		= @CustId,
	@ObjectTypeId	= 1,-- Object type : User
	@Date			= @startRun,
	@Data			= @logSPData,
	@OldData		= @logSPDataOld,
	@Duration		= @Duration

END

