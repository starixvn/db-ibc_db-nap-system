/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20201002@Helen
	Task: Change Index for perf tuning
	DB: DBCUST/CUSTDB
*/

USE [CustDB]
GO
DROP INDEX [ix_TOControl_Setting_matchid] ON [dbo].[TOControl_Setting] WITH ( ONLINE = OFF )
GO
CREATE NONCLUSTERED INDEX [ix_TOControl_Setting_matchid] ON [dbo].[TOControl_Setting] 
(
	[matchid] ASC
)
INCLUDE ( [PercentLevel],
[MaxTurnOver],
[TotalTurnOver],
[IsNotified],
[HouseTurnover]) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [DATA]
GO


