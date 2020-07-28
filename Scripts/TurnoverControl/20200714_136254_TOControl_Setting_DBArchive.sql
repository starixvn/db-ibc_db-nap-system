/*
   Created: 20200714@Max
	Task: SMA TO Control - Add block increasing TO Limit feature to specific SMAs - [Redmine: #136254]
	DB: DBARC/bodb_Archive
*/

USE bodb_Archive
GO

ALTER TABLE [dbo].TOControl_Setting_bk 
	ADD IsEventLockTOLimit BIT NULL DEFAULT(0), IsGlobalLockTOLimit BIT NULL DEFAULT(0);
GO


