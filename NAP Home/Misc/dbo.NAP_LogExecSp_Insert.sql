USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_LogExecSp_Insert]    Script Date: 8/1/2014 1:39:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_LogExecSp_Insert]  
	@UserId			INT,	
	@SPName			NVARCHAR(50)	= NULL,	
	@ActionId		INT				= NULL,	
	@ObjectId		INT				= NULL,
	@ObjectTypeId	INT				= NULL,		
	@Doing			NVARCHAR(MAX)	= NULL,
	@Date			DATETIME,
	@Data			NVARCHAR(MAX)	= NULL,
	@OldData		NVARCHAR(MAX)	= NULL,
	@Duration		INT				= NULL  
AS
/**
 * Created: 20121311@Kos
 * Task: Add new log user run sp
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
 *  - @UserId: UserId perform this action  
 *  - @CustId:
 *  - @ActionId: Log action ID
 *  - @TrackingValue: XML string format
 */

BEGIN  
 
SET NOCOUNT ON

	INSERT INTO dbo.LogExecSp
	(
		UserId,	
		SPName,	
		ActionId,
		ObjectId,
		ObjectTypeId,
		Doing,
		LogDate,
		Data,
		OldData,
		Duration
	)
	SELECT 
		@UserId,	
		@SPName,
		ActionId,	
		@ObjectId,
		@ObjectTypeId,
		@Doing,	
		@Date,
		@Data,
		@OldData,
		@Duration  
	FROM dbo.LogAction WITH (NOLOCK) 
	WHERE SPName = @SPName

END

GO
GRANT EXECUTE ON [dbo].[NAP_LogExecSp_Insert] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_LogExecSp_Insert] TO [vnteam] AS [dbo]