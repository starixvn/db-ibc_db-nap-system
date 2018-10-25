/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Site_GetAll]
    @Environment	VARCHAR(10)	= 'UAT'		-- 'UAT, 'LIVE'
    ,@IsActive		BIT			= NULL
AS
/*  
 * Created: 20120809@Edward
 * Task : Get all site
 * DB: DBPOL-NAP_UserControl
 *  
 * Revisions:
	- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
	     
 * Param's Explanation: 
*/
BEGIN
	SET NOCOUNT ON

	SELECT 
		SiteId
		,SiteName
		,Description
		,URL
		,TestURL
		,IsActive
		,Environment       
	FROM dbo.NAP_Sites WITH (NOLOCK)
	WHERE 
		(@Environment = 'UAT' OR (@Environment != 'UAT' AND Environment = @Environment))
		AND (@IsActive IS NULL OR (@IsActive IS NOT NULL AND IsActive = @IsActive))
END

GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetAll] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetAll] TO [vnteam] AS [dbo]