/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
   Created: 20201201@Max
	Task: Support CRM - Automate adding feedback If SMA reach Company Turnover Control - [Redmine: #145274]
	DB: DBARC/bodb_Archive
*/

USE bodb_Archive
GO

ALTER TABLE [dbo].[TOControl_Setting_bk] 
	ADD NotifiedPercentValue	 TINYINT  NULL,
	ModifiedDatePercentValue DATETIME NULL	
GO

