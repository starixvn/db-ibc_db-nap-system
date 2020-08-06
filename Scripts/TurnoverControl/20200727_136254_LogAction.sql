/*
	Created: 20200727@Max
	Task: SMA TO Control - Add block increasing TO Limit feature to specific SMAs - [Redmine: #136254]
	DB: dblog/bodb_CustomerLog
*/
USE bodb_CustomerLog
GO

INSERT INTO dbo.LogAction (ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameTH,ActionNameKO,IsInternal,ActionNameVI)
VALUES 
(761,'NAP_TOControl_GlobalSettingLockTOLimit_Update'
		,'Update TO Control''s Global Lock Status'
		,'Update TO Control''s Global Lock Status'
		,'Update TO Control''s Global Lock Status'
		,'Update TO Control''s Global Lock Status'
		,'Update TO Control''s Global Lock Status'
		,'Update TO Control''s Global Lock Status'
		,0
		,'Update TO Control''s Global Lock Status'
		)

,(762,'NAP_TOControl_MatchTurnoverLockTOLimit_Update'
		,'Update TO Control''s Event Lock Status'
		,'Update TO Control''s Event Lock Status'
		,'Update TO Control''s Event Lock Status'
		,'Update TO Control''s Event Lock Status'
		,'Update TO Control''s Event Lock Status'
		,'Update TO Control''s Event Lock Status'
		,0
		,'Update TO Control''s Event Lock Status'
		)
