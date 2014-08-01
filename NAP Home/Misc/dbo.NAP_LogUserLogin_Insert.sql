USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_LogUserLogin_Insert]    Script Date: 8/1/2014 1:40:17 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_LogUserLogin_Insert]
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
	DB: bodb_NAP
	Original:
	Revisions:	    
	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO bodb_NAPLog.dbo.NAPLog_UserLogin(
		UserId,
		SiteId,
		IP,
		LogDate,
		Doing,
		DomainName,
		BrowserName,
		Platform,
		CountryCode,
		Duration)
	VALUES (
		@UserId,
		@SiteId,
		@IP,
		@LogDate,
		@Doing,
		@DomainName,
		@BrowserName,
		@Platform,
		@CountryCode,
		@Duration)
END

GO
GRANT EXECUTE ON [dbo].[NAP_LogUserLogin_Insert] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_LogUserLogin_Insert] TO [vnteam] AS [dbo]