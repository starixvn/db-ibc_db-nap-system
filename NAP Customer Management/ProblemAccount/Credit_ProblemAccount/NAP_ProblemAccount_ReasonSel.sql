/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_ReasonSel
AS
/*
	Created: Elodie
	Date: 20200210
	Task : Reason dropdown box (Get all reason)
	DB: DBACC/bodb02

	Revisions:
		- 20200210@Elodie: Initial SP [Redmine:#127446]

	Parameter's explaination: 
	
*/
BEGIN	
	SELECT r.ReasonID, ReasonName
	FROM dbo.ProblemAccountReason r WITH(NOLOCK)
	WHERE IsCredit = 1
	ORDER BY ReasonID
END
GO
