/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_LicenseeAcknowledgementSel
AS
	/*
		Created: 20200210@Johnson
		Task: Problem Account - Manage Licensee Acknowledgement
		DB: DBCUST/bodb_Licensee
		
		Revisions:
			- 20200210@Johnson: initial sp [redmine:#128077]
	*/
BEGIN
	SET NOCOUNT ON
	
	SELECT LicenseeID,LicenseeName,IsActive, ISNULL(IsAcknowledgement,0) IsAcknowledgement
	FROM Licensees WITH(NOLOCK)
	ORDER BY IsActive DESC, LicenseeName ASC
END
GO	
