/*<info serverAlias="DBCUST-CustDB" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240228@July
	Task: SMA TO Control - Support to delete un-used tables on DBCUST/CustDB [Redmine:#201431]  
	DB: DBCUST-CustDB
	
*/
USE CustDB
GO

IF OBJECT_ID('TOControl_GlobalSetting_BK20180611_001','U') IS NOT NULL 
	DROP TABLE TOControl_GlobalSetting_BK20180611_001
GO

IF OBJECT_ID('TOControl_GlobalSetting_Match_BK20180611_002','U') IS NOT NULL 
	DROP TABLE TOControl_GlobalSetting_Match_BK20180611_002
GO

IF OBJECT_ID('TOControl_GlobalSetting_BK20180611','U') IS NOT NULL 
	DROP TABLE TOControl_GlobalSetting_BK20180611
GO

IF OBJECT_ID('TOControl_GlobalSetting_BK20180716','U') IS NOT NULL 
	DROP TABLE TOControl_GlobalSetting_BK20180716
GO

IF OBJECT_ID('DEL_TOControl_GlobalSetting_temp','U') IS NOT NULL 
	DROP TABLE DEL_TOControl_GlobalSetting_temp
GO