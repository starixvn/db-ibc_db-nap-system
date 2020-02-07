/*<info serverAlias="DBCUST-CustDB" executers="vnteam" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE DBA_CS_ProblemAccount_AddReason	
	@SubIssueTypeId SMALLINT, 
	@ReasonName VARCHAR(100),
	@ReasonNameCS NVARCHAR(100)
AS
/*
	Created: Elodie
	Date: 20190925
	Task : Add new reason
	DB: DBCUST/CustDB

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]
		- 20191202@Elodie: Add @SubIssueTypeId param [Redmine:#124722]
		- 20191202@Elodie: Add @@ReasonNameCS param [Redmine:#125495]

	Parameter's explaination: 
	
	Example: EXEC DBA_CS_ProblemAccount_AddReason @SubIssueTypeId = 37, @ReasonName = 'Irrigation Bet', @ReasonNameCS = N'灌水投注'
	
*/
BEGIN
	DECLARE @ReasonId TINYINT, @ReasonIdManual TINYINT

	EXEC DBTXN.bodb02.dbo.DBA_CS_ProblemAccount_AddSubIssueType @SubIssueTypeId = @SubIssueTypeId, @SubIssueType = @ReasonName, @SubIssueTypeCS = @ReasonNameCS

	IF @@ERROR = 0
	BEGIN
		SELECT @ReasonId = CAST(@SubIssueTypeId AS TINYINT)
		SELECT @ReasonIdManual = MAX(ReasonID) + 1 FROM ProblemAccountReason WITH (NOLOCK) WHERE ReasonID <> 255

		INSERT INTO ProblemAccountReason (ReasonID, ReasonName)	
		SELECT @ReasonIdManual, @ReasonName +'(M)'
		UNION ALL
		SELECT @ReasonId, @ReasonName
	END
	ELSE
	BEGIN
		SELECT 'Insert fail'
	END
END