/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Cust_Update]
	@CustId				INT,
	@FirstName			NVARCHAR (50)	=	NULL,
	@LastName			NVARCHAR (50)	=	NULL,
	@Email				NVARCHAR (50)	=	NULL,
	@GroupId			INT,
	@CurrentUserId		INT,
    @CurrentSiteId		INT,
	@LogDate			DATETIME,
	@LoginIP			VARCHAR(30)		=   '',
	@Language			VARCHAR(20)		=   'en-us',
	@ErrCode			INT				=   0			OUTPUT,
	@ErrMsg				NVARCHAR(1000)	=   ''			OUTPUT
AS

/*
	Created: 20120709@Edward
	Task : Update NAP user information and bodb02.dbo.Customer
	DB: DBPOL-NAP_UserControl
	Original:

	Revisions:
	    - 20150606@Kathy: Change link server DBTXN.CustDB to DBCust.CustDB [Redmine:#36216]
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
		
	Param's Explanation:
	• @CustId :
		= custid from bodb02.dbo.Customer and bodb02.dbo.custinfo
		= UserId from bodb_NAP.Users
	• @ErrCode: 
	• @ErrMsg: Error description.

	• Main	:	<root><xml path="r" />
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

	SET @startRun = GETDATE()
	
	-- Write log before update
	SET @xml = (
		SELECT cu.custid		AS '@ui'
				,cu.username	AS '@u'
				,g.GroupId		AS '@gi'
				,g.GroupName	AS '@g'
				,cu.firstname	AS '@f'
				,cu.lastname	AS '@l'
				,cu.email		AS '@e'
		FROM CUSTDB.dbo.Customer AS cu WITH(NOLOCK)
			INNER JOIN dbo.NAP_Users AS u WITH(NOLOCK) ON cu.custid = u.UserId
			LEFT JOIN dbo.NAP_Groups AS g WITH(NOLOCK) ON u.GroupId = g.GroupId
		WHERE cu.custid = @CustId 
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPDataOld = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')	

	-- Get old group before update
	DECLARE @dbGroupID INT

	SELECT @dbGroupID = GroupId
	FROM dbo.NAP_Users WITH (NOLOCK)
	WHERE UserId = @CustID

		-- Update user group if change group
	IF(@dbGroupID <> @GroupID)
		BEGIN	
			UPDATE dbo.NAP_Users
				SET GroupId		= @GroupID
			WHERE UserId	= @CustID		
		END
	IF @@ERROR <> 0
	BEGIN
			SELECT 
				@ErrCode = 103,
				@ErrMsg = N'Update fail UserId ' + COALESCE(CAST(@CustId AS VARCHAR(10)), SPACE(1)) 
			RETURN
	END	

	-- Update customer information
	EXEC [CustDB].[dbo].[NAP_AdminInfo_Update]
			@CustID		= @CustID,
			@FirstName	= @FirstName,
			@LastName	= @LastName,
			@Email		= @Email,
			@ErrCode	= @ErrCode OUTPUT,
			@ErrMsg		= @ErrMsg OUTPUT
	
	IF @ErrCode > 0
	BEGIN
		SELECT @ErrCode = @ErrCode, @ErrMsg = @ErrMsg
		RETURN	
	END

	-- Write log after update
	SET @xml = (
		SELECT @CustId			AS '@ui'
				,cu.username	AS '@u'
				,@GroupId		AS '@gi'
				,g.GroupName	AS '@g'
				,@FirstName		AS '@f'
				,@LastName		AS '@l'
				,@Email			AS '@e'
		FROM [bodb02].[dbo].Customer AS cu WITH(NOLOCK)
			INNER JOIN dbo.NAP_Users AS u WITH(NOLOCK) ON cu.custid = u.UserId
			LEFT JOIN dbo.NAP_Groups AS g WITH(NOLOCK) ON u.GroupId = g.GroupId
		WHERE cu.custid = @CustId 
		FOR XML PATH('r'), TYPE
	)	

	SET @logSPData = REPLACE(CONVERT(varchar(max), @xml), '" />', '"/"')		
		
	SET @endRun		= GETDATE()  
	SET @duration	= DATEDIFF(millisecond, @startRun, @endRun)   

	EXEC dbo.NAP_RunSP_WriteLog 
	@UserId			= @CurrentUserId,
	@SPName			= 'NAP_Cust_Update',
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
GRANT EXECUTE ON [dbo].[NAP_Cust_Update] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Cust_Update] TO [vnteam] AS [dbo]