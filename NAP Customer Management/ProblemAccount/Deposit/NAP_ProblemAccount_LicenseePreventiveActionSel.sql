/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_LicenseePreventiveActionSel	
AS
/*
	Created: Johnson
	Date: 20200219
	Task : Preventive action dropdown box
	DB: DBACC/bodb02

	Revisions:
		- 20200219@Johnson: Initial SP [Redmine:#128077]

	Parameter's explaination: 
			
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT ActionID, ActionName
	FROM ProblemAccountAction WITH(NOLOCK)
	WHERE isActive = 1
END
GO
