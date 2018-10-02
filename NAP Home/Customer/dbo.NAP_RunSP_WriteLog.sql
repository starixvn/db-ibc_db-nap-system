/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="1"></info>*/
--ALTER PROCEDURE [dbo].[NAP_RunSP_WriteLog]  
DECLARE	@UserId			INT,	
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
--AS
/*
	Created: 20180925@Helen
	Task: DB052.bodb_NAP Migration to DBCust
	DB: DBPOL/NAP_UserControl

	Revisions:
		 - 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
*/
--BEGIN
	SET NOCOUNT ON
	
	BEGIN TRY
		EXEC DBNAP.bodb_NAPLOG.dbo.NAP_LogRunSp_Insert 
		@UserId			= @UserId,
		@SPName			= @SPName,
		@ObjectId		= @ObjectId,
		@ObjectTypeId	= @ObjectTypeId, -- Object type : User
		@Language		= @Language,
		@SiteID			= @SiteID,
		@IP				= @IP,
		@Date			= @Date,
		@Data			= @Data,
		@OldData		= @OldData,
		@Duration		= @Duration
	END TRY
	BEGIN CATCH
		PRINT ERROR_NUMBER()
		PRINT ERROR_MESSAGE()
		RETURN
	END CATCH;

	
--END	 

