/*<info serverAlias="DBTXN-bodb02" executers="vnteam" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE DBA_CS_ProblemAccount_AddSubIssueType
	@SubIssueType VARCHAR(100)
AS
/*
	Created: Elodie
	Date: 20190925
	Task : Add new SubIssueType
	DB: DBTXN/bodb02

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]

	Parameter's explaination: 
	
	
*/
BEGIN
	INSERT INTO dbo.TicketVoiding_SubIssueType (IssueTypeId, SubIssueTypeName)	
	SELECT 11, @SubIssueType
END