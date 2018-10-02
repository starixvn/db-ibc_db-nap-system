/*<info serverAlias="DBNAP-bodb_NAPLOG" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_LogUserLogin_Insert_MNL]
	@UserId			INT,
	@SiteId			INT,
	@IP				VARCHAR(50),
	@LogDate		DATETIME,
	@Doing			VARCHAR(300)	= '',
	@DomainName		NVARCHAR(255)	= '',
	@BrowserName	NVARCHAR(255)	= '',
	@Platform		NVARCHAR(255)	= '',
	@CountryCode	VARCHAR(64)		= '',
	@Duration		INT				= NULL
AS
/*
	Created: 20120709@Edward
	Task :				
	DB: DBNAP/bodb_NAPLOG
	Original:
	Revisions:
		- 20180925@Helen: DB052.bodb_NAP Migration, Move to bodb_NAPLOG - [Redmine:100493]	    
	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON
END