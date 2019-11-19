/*<info serverAlias="DBAGE-bodb_Age" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_LimitLoss_ActionConfigSel]
AS
/*
	Created: Elodie
	Date: 20140526
	Task : Get action config
	DB: DBAGE/bodb_Age

	Revisions:
		- 20140526@Elodie: Initialize SP

	Parameter's explaination: 
	
	Example:  EXEC NAP_LimitLoss_ActionConfigSel
	
*/
SET NOCOUNT ON

SELECT a.LevelID, a.ActionID, a.Value
FROM dbo.LimitLoss_ActionConfig a WITH (NOLOCK)
GO