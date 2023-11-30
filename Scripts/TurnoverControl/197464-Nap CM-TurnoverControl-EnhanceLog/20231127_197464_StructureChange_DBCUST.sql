/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
/*
Created: 20231127@Max
Task : Nap CM - Turnover Control - TO control service was running with a delay of approximately 1 hour [Redmine: #197464]
DB: DBCUST-CustDB
*/
USE CustDB
GO
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--TOControl_Setting
ALTER TABLE TOControl_Setting ADD [CreatedDate] DATETIME, [ModifiedDate] DATETIME	
GO
ALTER TABLE TOControl_Setting ADD  CONSTRAINT [DF_Transition_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO
ALTER TABLE TOControl_Setting ADD  CONSTRAINT [DF_Transition_ModifiedDate]  DEFAULT (getdate()) FOR [ModifiedDate]
GO

--TOControl_TransitionProcessedLog
CREATE TABLE [dbo].[TOControl_TransitionProcessedLog](
	[MinRowId] [bigint] NOT NULL,
	[MaxRowId] [bigint] NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
) ON [DATA]
GO

ALTER TABLE [dbo].[TOControl_TransitionProcessedLog] ADD  CONSTRAINT [DF_TransitionProcessedLog_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

CREATE CLUSTERED INDEX [IX_TransitionProcessedLog_CreatedDate] ON [dbo].[TOControl_TransitionProcessedLog]
(
	[CreatedDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
GO