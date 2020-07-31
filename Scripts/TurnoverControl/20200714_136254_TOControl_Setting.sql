/*
   Created: 20200714@Max
	Task: SMA TO Control - Add block increasing TO Limit feature to specific SMAs - [Redmine: #136254]
	DB: DBCUST/CustDB
*/

USE CustDB
GO

ALTER TABLE [dbo].[TOControl_Setting]
	ADD IsEventLockTOLimit BIT NULL, IsGlobalLockTOLimit BIT NULL;
GO

ALTER TABLE [dbo].[TOControl_Setting] ADD  CONSTRAINT [DF_TOControl_Setting_IsEventLockTOLimit]  DEFAULT ((0)) FOR [IsEventLockTOLimit]
GO

ALTER TABLE [dbo].[TOControl_Setting] ADD  CONSTRAINT [DF_TOControl_Setting_IsGlobalLockTOLimit]  DEFAULT ((0)) FOR [IsGlobalLockTOLimit]
GO


