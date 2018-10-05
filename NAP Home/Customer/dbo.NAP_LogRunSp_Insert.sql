/*<info serverAlias="DBNAP-bodb_NAPLog" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_LogRunSp_Insert]  
	@UserId			INT,	
	@SPName			NVARCHAR(50)	= NULL,		
	@ObjectId		INT				= NULL,
	@ObjectTypeId	INT				= NULL,
	@Language       VARCHAR(20)		= NULL,
	@SiteID			tinyint			= NULL,
	@IP				varchar(50)		= NULL,
	@Date			DATETIME,
	@Data			NVARCHAR(MAX)	= NULL,
	@OldData		NVARCHAR(MAX)	= NULL,
	@Duration		INT				= NULL  
AS
/*
	Created: 20121311@Kos
	Task: Add new log user run sp
	DB: DBNAP/bodb_NAPLog

	Revisions:
		 - 20180925@Helen: Missing GIT Source Code, Get Code from PRO [Redmine:100493]
		     
	Param's Explanation: 
		 - @UserId: UserId perform this action  
		 - @CustId:
		 - @ActionId: Log action ID
		 - @TrackingValue: XML string format
*/
BEGIN
	SET NOCOUNT ON

	IF @SPName LIKE '%_xtest'
		SELECT @SPName = LEFT(@SPName, LEN(@SPName) - 6)
	ELSE IF @SPName LIKE '%_xpre'
		OR @SPName LIKE '%_UAT1'
		OR @SPName LIKE '%_UAT2'
		OR @SPName LIKE '%_UAT3'
		OR @SPName LIKE '%_UAT4'
		SELECT @SPName = LEFT(@SPName, LEN(@SPName) - 5)
  
	DECLARE @langid tinyint, @actionid smallint
	IF @Language is NOT NULL
		SELECT @langid = [langid] 
		FROM dbo.NAPLog_Language WITH(NOLOCK) 
		WHERE language = @language
	
	SELECT @actionid = actionID
	FROM dbo.NAPLog_Action WITH(NOLOCK)
	WHERE SPName = @SPName

	INSERT INTO dbo.NAPLog_RUNSP(
		UserId, SPName, ActionId, ObjectId, ObjectTypeId, 
		langID, siteID, IP, LogDate, Duration
	)
	VALUES (@UserId, @SPName, @actionid, @ObjectId, @ObjectTypeId, 
		@langid, @SiteID, @IP, @Date, @Duration	
	)

	IF @@ERROR = 0
	INSERT INTO dbo.NAPLOG_RUNSP_Detail(ID, ActionID, Data, OldData)
	VALUES(@@IDENTITY, @actionid, @Data, @OldData)
END	 

