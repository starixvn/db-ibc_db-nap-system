/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_ActionSel
AS
/*
	Created: Elodie
	Date: 20200210
	Task : Preventive action dropdown box
	DB: DBACC/bodb02

	Revisions:
		- 20200210@Elodie: Initial SP [Redmine:#127446]

	Parameter's explaination: 
	
*/
BEGIN	
	SELECT ActionID, ActionName
	FROM dbo.ProblemAccountAction WITH(NOLOCK)
	WHERE IsActive = 1
END
GO
