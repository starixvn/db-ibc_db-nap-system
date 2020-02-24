/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_LicenseePreventiveActionSel	
AS
/*
	Created: Johnson
	Date: 20200224
	Task : Constraint between Preventive Action and Reason
	DB: DBACC/bodb02

	Revisions:
		- 20200224@Johnson: Initial SP [Redmine:#128077]

	Parameter's explaination: 
			
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT p2.ActionID, p2.ActionName, p3.ReasonID, p3.ReasonName
	FROM ProblemAccountReasonAction p1 WITH(NOLOCK)
		INNER JOIN ProblemAccountAction p2 WITH(NOLOCK) ON p1.ActionID = p2.ActionID
		INNER JOIN ProblemAccountReason p3 WITH(NOLOCK) ON p1.ReasonID = p3.ReasonID
	WHERE p2.isActive = 1
		AND p3.ReasonID > 100
		AND p3.isLicensee = 1
	ORDER BY p2.ActionID, p3.ReasonID	
END
GO
