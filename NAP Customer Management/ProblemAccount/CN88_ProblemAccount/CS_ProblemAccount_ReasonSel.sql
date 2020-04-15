/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE CS_ProblemAccount_ReasonSel
	@Mode TINYINT = 1
AS
/*
	Created: Elodie
	Date: 20190808
	Task : Reason dropdown box
	DB: DBACC/bodb02

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]

	Parameter's explaination: 
		@Mode:	1: Get manual reason to mark new problem account
				2: Get all reason
	
*/
BEGIN
	IF @Mode = 1
	BEGIN
		SELECT ReasonID, ReasonName
		FROM dbo.ProblemAccountReason WITH(NOLOCK)
		WHERE ReasonID > 100
			AND IsCN88 = 1
		ORDER BY ReasonID
	END
	ELSE
	BEGIN
		SELECT ReasonID, ReasonName
		FROM dbo.ProblemAccountReason WITH(NOLOCK)
		WHERE IsCN88 = 1
		UNION ALL
		SELECT 0, 'None'
		ORDER BY ReasonID
	END
END
GO
