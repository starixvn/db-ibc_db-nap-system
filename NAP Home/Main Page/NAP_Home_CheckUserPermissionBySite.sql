/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Home_CheckUserPermissionBySite] 
	@UserId INT
	,@SiteId INT
	,@Environment NVARCHAR(10) = 'UAT'
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
    ,@ErrCode INT = 0 OUTPUT
AS
/*	Created: 20140808@Sophia
	Task: Check permission of user can access the menus of site  
	DB: DBPOL-NAP_UserControl
	
	Revisions:	
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	
	Param's Explanation:
	- @UserId: User ID.
	- @SiteId: Site ID.
	- @MenuId: Menu ID
	- @Environment:
		'UAT': The site is on UAT environment.
		'LIVE': The site is on Production environment.
      
    Example: 
		DECLARE @ErrCode INT, @ErrMsg NVARCHAR(200)
			EXEC dbo.[NAP_Home_CheckUserPermissionBySite] @UserId=4534038, @SiteId=1, @Environment='UAT', @ErrMsg = @ErrMsg OUTPUT, @ErrCode = @ErrCode OUTPUT
		SELECT @ErrCode, @ErrMsg 
*/
BEGIN
	SET NOCOUNT ON;
	SELECT @ErrMsg = '',@ErrCode = 0
	
	IF NOT EXISTS (			
					SELECT TOP 1 1
					FROM dbo.NAP_Sites AS SI WITH (NOLOCK)
						INNER JOIN dbo.NAP_UserSite AS US WITH (NOLOCK)
								ON SI.SiteId = US.SiteId
						INNER JOIN dbo.NAP_SiteURL AS SU WITH (NOLOCK)
								ON SI.SiteId = SU.SiteId
					WHERE US.UserId = @UserId
						AND US.SiteId = @SiteId
						AND SI.IsActive = 1
						AND US.IsActive = 1
						AND SU.IsActive = 1
						AND SU.Environment = @Environment
						AND CASE WHEN @Environment <> 'UAT' THEN SI.Environment ELSE @Environment END = @Environment
					)
			BEGIN 
				DECLARE @SiteName VARCHAR(50)
				
				SELECT @SiteName = SiteName
				FROM   dbo.NAP_Sites WITH (NOLOCK)
				WHERE  SiteId = @SiteId

				SELECT	@ErrMsg = 'You are not authorized to access the site ' + @SiteName,
						@ErrCode = 102   
				RETURN
			END
		

END
GO

GRANT EXECUTE ON [dbo].[NAP_Home_CheckUserPermissionBySite] TO [bodbAdminNet] AS [dbo]
GO


