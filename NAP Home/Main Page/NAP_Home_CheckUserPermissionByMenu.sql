/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Home_CheckUserPermissionByMenu] 
	@UserId INT
	,@SiteId INT
	,@MenuId INT
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
			EXEC dbo.[NAP_Home_CheckUserPermissionByMenu] @UserId=8, @SiteId=1,@MenuId = 4,  @Environment='UAT', @ErrMsg = @ErrMsg OUTPUT, @ErrCode = @ErrCode OUTPUT
		SELECT @ErrCode, @ErrMsg 
*/
BEGIN
	SET NOCOUNT ON;
	SELECT @ErrMsg = '',@ErrCode = 0

	IF NOT EXISTS (
						SELECT	TOP 1 1		
						FROM (
									SELECT CASE 
											WHEN ISNULL(UP.FunctionId, 0) = 0 THEN GP.FunctionId
											ELSE UP.FunctionId
											END AS FunctionId
										,CASE 
											WHEN ISNULL(UP.Policy, 0) < ISNULL(GP.Policy, 0) THEN ISNULL(GP.Policy, 0)
											ELSE ISNULL(UP.Policy, 0)
											END AS Policy
									FROM	(
												-- Get function permissions of an user on a site.
												SELECT	FunctionId, Policy
												FROM	dbo.NAP_UserFunction WITH (NOLOCK)
												WHERE	UserId = @UserId
														AND SiteId = @SiteId
											) AS UP
										FULL OUTER JOIN 
											(
												-- Get group permissions of an user on a site.
												SELECT	GF.FunctionId, GF.Policy
												FROM	dbo.NAP_GroupFunction AS GF WITH (NOLOCK)
													INNER JOIN dbo.NAP_Users AS US WITH (NOLOCK)
														ON GF.GroupId = US.GroupId
												WHERE	US.UserId = @UserId
														AND GF.SiteId = @SiteId
											) AS GP
										ON UP.FunctionId = GP.FunctionId
								) AS UF
							INNER JOIN dbo.NAP_MenuItems AS MN WITH (NOLOCK)
								ON	UF.FunctionId = MN.FunctionId
									AND UF.Policy >= MN.Policy
							INNER JOIN dbo.NAP_Functions AS FT WITH (NOLOCK)
								ON	UF.FunctionId = FT.FunctionId
						WHERE	(
									@Environment = 'UAT' OR (@Environment <> 'UAT' AND @Environment = MN.Environment AND @Environment = FT.Environment)
								)
							AND ISNULl(MN.URL,'') <> ''
							AND MN.MenuItemId = @MenuId
							AND MN.IsActive = 1
							AND FT.IsActive = 1
					)
			BEGIN 
				DECLARE @MenuItemName NVARCHAR(50) 
				
				SELECT  @MenuItemName = MenuItemName
				FROM	dbo.NAP_MenuItems WITH (NOLOCK)
				WHERE	MenuItemId = @MenuId
				

				SELECT	@ErrMsg = 'You are not authorized to access the function ' +@MenuItemName  ,
						@ErrCode = 101   
				RETURN
			END
		

END
GO

GRANT EXECUTE ON [dbo].[NAP_Home_CheckUserPermissionByMenu] TO [bodbAdminNet] AS [dbo]
GO 