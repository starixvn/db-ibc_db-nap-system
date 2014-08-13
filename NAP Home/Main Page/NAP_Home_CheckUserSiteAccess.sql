ALTER PROCEDURE [dbo].[NAP_Home_CheckUserSiteAccess]
	@UserId INT
	,@Environment NVARCHAR(10) = 'UAT'
    ,@IsAccess BIT = 0 OUTPUT
AS

/*	Created: 20140808@Sophia
	Task: Check permission of user can access NAP Home page 
	DB: DBNAP/bodb_NAP
	
	Revisions:			
	
	Param's Explanation:
	- @UserId: User ID
	- @Environment:
		'UAT': The site is on UAT environment.
		'LIVE': The site is on Production environment.
    - @IsAccess:
		0: Can not access NAP home
		1: Can access NAP home
    Example: 
		DECLARE @IsAccess BIT 
			EXEC dbo.[NAP_Home_CheckUserSiteAccess] @UserId=4534038, @Environment='UAT', @IsAccess = @IsAccess OUTPUT
		SELECT @IsAccess
*/

BEGIN 
	SET NOCOUNT ON 

	SELECT	@IsAccess = 0
		
	IF EXISTS (			
					SELECT TOP 1 1
					FROM dbo.Sites AS SI WITH (NOLOCK)
						INNER JOIN dbo.UserSite AS US WITH (NOLOCK)
								ON SI.SiteId = US.SiteId
						INNER JOIN dbo.SiteURL AS SU WITH (NOLOCK)
								ON SI.SiteId = SU.SiteId
					WHERE US.UserId = @UserId
						AND SI.IsActive = 1
						AND US.IsActive = 1
						AND SU.IsActive = 1
						AND SU.Environment = @Environment
						AND CASE WHEN @Environment <> 'UAT' THEN SI.Environment ELSE @Environment END = @Environment
					)
	BEGIN				
		SELECT	@IsAccess = 1		
	END		

END 
GO 
GRANT EXECUTE ON [dbo].[NAP_Home_CheckUserSiteAccess] TO [bodbAdminNet]
GO
  