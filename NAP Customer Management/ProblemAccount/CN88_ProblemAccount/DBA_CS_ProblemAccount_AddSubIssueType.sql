/*<info serverAlias="DBTXN-bodb02" executers="vnteam" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE DBA_CS_ProblemAccount_AddSubIssueType	
	@SubIssueTypeId SMALLINT,
	@SubIssueType VARCHAR(100),
	@SubIssueTypeCS NVARCHAR(100)
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

	INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName, SubIssueTypeNameCS)	
	SELECT @SubIssueTypeId, 11, @SubIssueType, @SubIssueTypeCS

	INSERT INTO TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId)
	SELECT 34, @SubIssueTypeId

	INSERT INTO TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
	SELECT 0, @SubIssueTypeId, 'Abnormal bet', N'由于非正常投注'

	SET IDENTITY_INSERT TicketVoiding_SubIssueType OFF
END