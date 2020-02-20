/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_ReasonSel
	@Mode TINYINT = 1,
	@ActionId TINYINT = NULL
AS
/*
	Created: Elodie
	Date: 20200210
	Task : Reason dropdown box
	DB: DBACC/bodb02

	Revisions:
		- 20200210@Elodie: Initial SP [Redmine:#127446]

	Parameter's explaination: 
		@Mode:	1: Get manual reason to mark new problem account
				2: Get all reason
	
*/
BEGIN	
	IF @Mode = 1
	BEGIN
		SELECT ReasonID, ReasonName
		FROM dbo.ProblemAccountReason r WITH(NOLOCK)
			INNER JOIN ProblemAccountReasonAction ra WITH (NOLOCK) ON r.ReasonID = ra.ReasonID
		WHERE ReasonID > 100
			AND IsCredit = 1
			AND ra.ActionID = @ActionId
		ORDER BY ReasonID
	END
	ELSE
	BEGIN
		SELECT ReasonID, ReasonName
		FROM dbo.ProblemAccountReason WITH(NOLOCK)
		WHERE IsCredit = 1
		ORDER BY ReasonID
	END
END
GO
