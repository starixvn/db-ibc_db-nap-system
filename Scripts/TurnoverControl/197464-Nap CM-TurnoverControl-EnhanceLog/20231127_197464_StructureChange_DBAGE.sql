/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
/*
Created: 20231127@Max
Task : Nap CM - Turnover Control - TO control service was running with a delay of approximately 1 hour [Redmine: #197464]
DB: DB052/DB053.bodb02
*/
USE bodb02
GO
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--TOControl_Transition
ALTER TABLE TOControl_Transition ADD [CreatedDate] DATETIME
GO
ALTER TABLE TOControl_Transition ADD  CONSTRAINT [DF_Transition_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

CREATE NONCLUSTERED INDEX [IX_Transition_CreatedDate] ON TOControl_Transition
(
	[CreatedDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
GO

--TOControl_TicketDetails_Insert
ALTER TABLE TOControl_TicketDetails_Insert ADD [CreatedDate] DATETIME
GO
ALTER TABLE TOControl_TicketDetails_Insert ADD  CONSTRAINT [DF_TicketDetails_Insert_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

CREATE NONCLUSTERED INDEX [IX_TicketDetails_Insert_CreatedDate] ON TOControl_TicketDetails_Insert
(
	[CreatedDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
GO

--TOControl_TicketDetails_Update
ALTER TABLE TOControl_TicketDetails_Update ADD [CreatedDate] DATETIME
GO
ALTER TABLE TOControl_TicketDetails_Update ADD  CONSTRAINT [DF_TicketDetails_Update_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

CREATE NONCLUSTERED INDEX [IX_TicketDetails_Update_CreatedDate] ON TOControl_TicketDetails_Update
(
	[CreatedDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
GO