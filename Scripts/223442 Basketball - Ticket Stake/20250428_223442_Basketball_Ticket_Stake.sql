/*<info serverAlias="DBCUST-CustDB,DBACC-bodb02"></info>*/
/*
	Created: 20250428@Logan
	DB: DBCUST/CustDB
	Task:  [NAP CM] Customer - Bet Restriction - Basketball - Ticket Stake [223442]
*/
--===================================================================================
ALTER TABLE BetRestriction_Customer ADD LeastStake MONEY  NULL
GO