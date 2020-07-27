/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20200714@Max
	Task: SMA TO Control - Add block increasing TO Limit feature to specific SMAs - [Redmine: #136254]
	DB: DBCUST/CustDB
*/
USE CustDB
GO

ALTER TABLE [dbo].TOControl_GlobalSetting ADD IsGlobalLockTOLimit BIT NULL DEFAULT(0)
GO

