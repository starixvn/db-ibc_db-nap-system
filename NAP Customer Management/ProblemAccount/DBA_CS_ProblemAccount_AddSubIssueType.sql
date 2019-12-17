/*<info serverAlias="DBTXN-bodb02" executers="vnteam" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE DBA_CS_ProblemAccount_AddSubIssueType	
	@SubIssueTypeId SMALLINT,
	@SubIssueType VARCHAR(100)
AS
/*
	Created: Elodie
	Date: 20190925
	Task : Add new SubIssueType
	DB: DBTXN/bodb02

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]
		- 20191202@Elodie: Add @SubIssueTypeId param [Redmine:#124722]

	Parameter's explaination: 
	
	
*/
BEGIN
	SET IDENTITY_INSERT TicketVoiding_SubIssueType ON

	INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName)	
	SELECT @SubIssueTypeId, 11, @SubIssueType

	INSERT INTO TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId)
	SELECT 34, @SubIssueTypeId

	SET IDENTITY_INSERT TicketVoiding_SubIssueType OFF
END