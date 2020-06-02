/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_AllTypeSelect] 
	@UserID INT = 0
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - select Site for dropdown
	DB: DBACC-bodb02
	Original:

	Revisions:  
	- 20200602@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:

	Example: 
	EXEC NAP_BLControl_AllTypeSelect @UserID = 8

	*/
BEGIN
	SELECT SiteID,Site
	FROM dbo.[Site] WITH(NOLOCK)
END
GO


