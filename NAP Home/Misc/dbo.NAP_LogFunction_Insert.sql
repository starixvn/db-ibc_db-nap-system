USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_LogFunction_Insert]    Script Date: 8/1/2014 1:39:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_LogFunction_Insert]
	@FunctionId		INT,
	@SiteId			INT,
	@UserId			INT,		
	@Param			VARCHAR(MAX),
	@LogDate		DATETIME,
	@IP				VARCHAR(50),
	@BrowserName	NVARCHAR(255)	= ''	
	
	
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
	
	INSERT INTO bodb_NAPLog.dbo.NAPLog_Function(
			FunctionId,
			SiteId,
			UserId,
			Params,
			LogDate,
			IP,
			BrowserName)
	VALUES(
			@FunctionId,
			@SiteId,
			@UserId,
			@Param,
			@LogDate,
			@IP,
			@BrowserName
			)
END

GO
GRANT EXECUTE ON [dbo].[NAP_LogFunction_Insert] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_LogFunction_Insert] TO [vnteam] AS [dbo]