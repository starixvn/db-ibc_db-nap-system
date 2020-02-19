/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_LicenseeReasonSel	
AS
/*
	Created: Johnson
	Date: 20200217
	Task : Reason dropdown box
	DB: DBACC/bodb02

	Revisions:
		- 20200217@Johnson: Initial SP [Redmine:#128077]

	Parameter's explaination: 
			
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT ReasonID,ReasonName
	FROM ProblemAccountReason WITH(NOLOCK)
	WHERE IsLicensee = 1
END
GO
