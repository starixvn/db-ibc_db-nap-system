/*<info serverAlias="IRS_DBTP-bodb02,DBCustRepl-ReplCustDB" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250505@Logan	
	Task: In-House
	DB: IRS_DBTP-bodb02,DBCustRepl-ReplCustDB
	
	Revisions:
		- 20250505@Logan: Created [RedmineID: #223442]

	Example:			
*/
DROP PROCEDURE dbo.Repl_PutBetRestriction_Customer_Dist ;
DROP TYPE [dbo].[TVP_ReplBetRestriction_Customer] ;
CREATE TYPE [dbo].[TVP_ReplBetRestriction_Customer] AS TABLE (
	[CustID] [INT] NOT NULL
	,[SportType] [SMALLINT] NOT NULL
	,[LiveBetAccept] [SMALLINT] NULL
	,[SeizeBetTicket] [TINYINT] NULL
	,[MaxBet] [MONEY] NULL
	,[MaxPerMatch] [MONEY] NULL
	,[FollowAccount] [INT] NULL
	,[LeagueGroupID] [VARCHAR](4000) NULL
	,[AccumulateBalance] [BIT] NULL
	,[LeastStake] [MONEY] NULL
	,[RepUpdateTime] [DATETIME2](7) NOT NULL
	,[isDeleted] [BIT]
	,[_FetchedTime] [DATETIME2](7)
)
GO
GRANT EXECUTE ON TYPE::[dbo].[TVP_ReplBetRestriction_Customer] TO [repl_ap] AS [dbo]
GO
/***************************************************************************/




