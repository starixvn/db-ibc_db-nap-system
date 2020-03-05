/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_CurrencySel
AS
/*
	Created: Elodie
	Date: 20200210
	Task : Currency dropdown box
	DB: DBACC/bodb02

	Revisions:
		- 20200210@Elodie: Initial SP [Redmine:#127446]

	Parameter's explaination: 
	
*/
BEGIN	
	SELECT exchangeid, currency
	FROM dbo.Exchange WITH(NOLOCK)	
END
GO
