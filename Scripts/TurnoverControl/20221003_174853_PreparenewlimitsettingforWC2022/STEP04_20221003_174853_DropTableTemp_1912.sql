/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20221003@July
	Task: SMA TO Control - Prepare new limit setting for World Cup 2022 - [Redmine: #174853]
	DB: DBCUST-CustDB

	Noted: Apply for soccer (no increase for OS)
*/

USE CustDB 
GO

DROP TABLE [dbo].[TOControl_GlobalSetting_History_tmp]