/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE CS_ProblemAccount_CustomerList
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@RoleId				TINYINT,
	@CurrrencyID		INT,
	@Status				TINYINT,
	@IsReduce			BIT,
	@ReasonId			TINYINT,
	@UserSearch			VARCHAR(50),
	@IsSearchDownline	BIT,
	@OrderType			TINYINT,
	@UserID				INT
AS
/*
	Created: Elodie
	Date: 20190808
	Task : Add new problem account
	DB: DBCUST/CustDB

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]

	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	SELECT 
		0 AS CustId, 
		'' AS Headline,
		'' AS Super,
		'' AS Master,
		'' AS Agent, 
		'' AS Member,
		6 AS BitmapColor,
		7 AS Status,
		8 AS SuperMPM,
		9 AS SuperMaxBet,
		8 AS MasterMPM,
		9 AS MasterMaxBet,
		8 AS AgentMPM,
		9 AS AgentMaxBet,
		8 AS MemberMPM,
		9 AS MemberMaxBet,
		10 AS MarkDate,
		11 AS Comment,
		12 AS AbnormalBetNumber

	SELECT 0 AS Custid, 1 AS CreateDate, '' AS Reason, '' AS Username
END
GO
