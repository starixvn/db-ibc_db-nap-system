/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20201127@Max
	Task: Support CRM - Automate adding feedback If SMA reach Company Turnover Control - [Redmine: #145274]
	DB: DBCUST-CustDB
*/

USE CustDB
GO

CREATE TABLE TOControl_Setting_History
(
	LogID INT IDENTITY(1,1), 
	CustID INT, 
	Matchid INT, 
	MaxTurnover MONEY, 
	HouseTurnover MONEY,
	TotalTurnover MONEY	,
	PercentLevel TINYINT, 
	IsGroupHeadLine	BIT, 
	ProfileID SMALLINT, 
	NotifiedPercentValue INT, 
	ModifiedDate DATETIME
)
GO
CREATE CLUSTERED INDEX [ix_CustID_MatchID_IsGroupHeadLine_ProfileID] ON [dbo].[TOControl_Setting_History]
(
	[CustID] ASC,
	[Matchid] ASC,
	[IsGroupHeadLine] ASC,
	[ProfileID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO
				  