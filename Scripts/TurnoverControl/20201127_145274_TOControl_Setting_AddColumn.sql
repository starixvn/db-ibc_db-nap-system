/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20201127@Max
	Task: Support CRM - Automate adding feedback If SMA reach Company Turnover Control - [Redmine: #145274]
	DB: DBCUST-CustDB
*/

USE CustDB
GO

ALTER TABLE [dbo].[TOControl_Setting] ADD
	NotifiedPercentValue	 TINYINT  NULL,
	ModifiedDatePercentValue DATETIME NULL				  
