/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210504@July
	Task: SMA TO Control - Change Global Setting for EC2021 - [Redmine: #130912]
	DB: DBCUST-CustDB
*/

USE CustDB 


--STEP 1: script to save all current data into new physical TOControl_GlobalSetting-> TOControl_GlobalSetting_History
CREATE TABLE [dbo].[TOControl_GlobalSetting_History_tmp](
	[CustID] [int] NOT NULL,
	[MaxTurnOver] [money] NOT NULL,
	[Sporttype] [smallint] NOT NULL,
	[IsGroupHeadLine] [bit] NOT NULL,
	[ProfileID] [smallint] NOT NULL,
	[IsGlobalLockTOLimit] [bit] NULL,
 CONSTRAINT [PK_TO_ControlGlobalSetting_History_tmp] PRIMARY KEY CLUSTERED 
(
	[CustID] ASC,
	[Sporttype] ASC,
	[IsGroupHeadLine] ASC,
	[ProfileID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
) ON [DATA]
GO
ALTER TABLE [dbo].[TOControl_GlobalSetting_History_tmp] ADD  DEFAULT ((0)) FOR [IsGlobalLockTOLimit]

GO



