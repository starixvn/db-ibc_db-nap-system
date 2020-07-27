/*
   Created: 20200714@Max
	Task: SMA TO Control - Add block increasing TO Limit feature to specific SMAs - [Redmine: #136254]
	DB: bodb02 - Replicated Server FOR CustDB_ExchangeDaily 
*/
USE bodb02
GO

ALTER TABLE [dbo].TOControl_GlobalSetting ADD IsGlobalLockTOLimit BIT NULL DEFAULT(0)
GO
