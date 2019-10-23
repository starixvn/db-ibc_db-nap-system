/*<info serverAlias="DBONUSER-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_Customer_RobotSite_Sel]	
AS
/*
		Created: Johnson
		Date: 2019-09-17
		Task: Get all sites in system
		DB: DBONUSER/bodb02
		
		Revision:
			- 20190917@Johnson: Initial sp [redmine:#119714]
		Parameter's Explanation:						
	*/ 
BEGIN
	SET NOCOUNT ON
	
	SELECT siteid, site, isDeposit
	FROM site WITH(NOLOCK)
	WHERE isActive = 1
	ORDER BY isDeposit asc, site ASC
END	
GO
	