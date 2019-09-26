/*<info serverAlias="DBCUST-CustDB" executers="vnteam" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE DBA_CS_ProblemAccount_AddReason	
	@ReasonName VARCHAR(100)
AS
/*
	Created: Elodie
	Date: 20190925
	Task : Add new reason
	DB: DBCUST/CustDB

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]

	Parameter's explaination: 
	
	Example: EXEC DBA_CS_ProblemAccount_AddReason @ReasonName = 'AB Bet'
	
*/
BEGIN
	DECLARE @ReasonId TINYINT, @ReasonIdManual TINYINT

	EXEC DBTXN.bodb02.dbo.DBA_CS_ProblemAccount_AddSubIssueType @SubIssueType = @ReasonName

	SELECT @ReasonId = SubIssueTypeId 
	FROM DBTXN.bodb02.dbo.TicketVoiding_SubIssueType WITH (NOLOCK) 
	WHERE SubIssueTypeName = @ReasonName

	IF @ReasonId IS NOT NULL
	BEGIN
		SELECT @ReasonIdManual = MAX(ReasonID) + 1 FROM ProblemAccountReason WITH (NOLOCK) WHERE ReasonID <> 255

		INSERT INTO ProblemAccountReason (ReasonID, ReasonName)	
		SELECT @ReasonIdManual, @ReasonName +'(M)'
		UNION ALL
		SELECT @ReasonId, @ReasonName
	END
END