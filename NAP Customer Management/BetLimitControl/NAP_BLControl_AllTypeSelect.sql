/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_AllTypeSelect] 
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - select Type for dropdown
	DB: DBACC-bodb02
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:

	Example: 
	EXEC NAP_BLControl_AllTypeSelect 

	*/
BEGIN
	SELECT  BetLimitTypeID,
			BetLimitType
	FROM BetLimitControlType t WITH(NOLOCK)
	ORDER BY BetLimitType
END
GO


