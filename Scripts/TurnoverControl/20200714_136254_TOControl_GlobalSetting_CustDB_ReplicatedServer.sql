/*
	Created: 20200714@Max
	Task: SMA TO Control - Add block increasing TO Limit feature to specific SMAs - [Redmine: #136254]
	DB: DBCUST/CustDB & bodb02 - Replicated Server FOR CustDB_ExchangeDaily
*/

ALTER TABLE [dbo].[TOControl_GlobalSetting] ADD IsGlobalLockTOLimit BIT NULL DEFAULT(0)
GO

ALTER TABLE [dbo].[TOControl_GlobalSetting] ADD  CONSTRAINT [DF_TOControl_GlobalSetting_IsGlobalLockTOLimit]  DEFAULT ((0)) FOR [IsGlobalLockTOLimit]
GO
