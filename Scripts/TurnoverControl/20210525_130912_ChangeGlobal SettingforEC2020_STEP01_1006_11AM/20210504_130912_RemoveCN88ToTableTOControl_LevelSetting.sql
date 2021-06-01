/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210504@July
	Task: SMA TO Control - Change Global Setting for EC2021 - [Redmine: #130912]
	DB: DBCUST-CustDB
*/
USE CustDB
GO

DELETE FROM dbo.TOControl_LevelSetting WHERE SiteID = 329 --CN88
