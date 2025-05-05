/*<info serverAlias="DBCustRepl-ReplCustDB"></info>*/
/*
	Created: 20250428@Logan
	DB: DBCustRepl/ReplCustDB
	Task:  [NAP CM] Customer - Bet Restriction - Basketball - Ticket Stake [223442]
*/
--===================================================================================
ALTER TABLE BetRestriction_Customer ADD LeastStake MONEY  NULL
GO