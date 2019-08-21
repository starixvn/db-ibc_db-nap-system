/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE CS_ProblemAccount_ReasonSel
AS
/*
	Created: Elodie
	Date: 20190808
	Task : Reason dropdown box
	DB: DBACC/bodb02

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]

	Parameter's explaination: 
	
*/
BEGIN
		SELECT ReasonID, ReasonName
		FROM dbo.ProblemAccountReason WITH(NOLOCK)
END
GO
