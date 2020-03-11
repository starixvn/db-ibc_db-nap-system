/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_LicenseeReasonSel	
	@Mode TINYINT = 1
AS
/*
	Created: Johnson
	Date: 20200217
	Task : Reason dropdown box
	DB: DBACC/bodb02

	Revisions:
		- 20200217@Johnson: Initial SP [Redmine:#128077]

	Parameter's explaination: 
		@Mode:	1: Get manual reason to mark new problem account
				2: Get all reason
			
*/
BEGIN
	SET NOCOUNT ON
	IF @Mode = 1
	BEGIN
		SELECT ReasonID,ReasonName
		FROM ProblemAccountReason WITH(NOLOCK)
		WHERE IsLicensee = 1
			AND ReasonID > 100
	END
	ELSE 
	BEGIN
		SELECT ReasonID,ReasonName
		FROM ProblemAccountReason WITH(NOLOCK)
		WHERE IsLicensee = 1
	END
END
GO
