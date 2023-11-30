/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
/*
Created: 20231127@Max
Task : Nap CM - Turnover Control - TO control service was running with a delay of approximately 1 hour [Redmine: #197464]
DB: DB052/DB053.bodb02
*/
USE bodb02
GO

--TOControl_Transition
DECLARE @MaxID BIGINT = 0
SELECT TOP (1) @MaxID = CONVERT(BIGINT, VValue)
FROM DBCUST.CustDB.dbo.TOConTrol_GlobalVariables WITH (ROWLOCK)
WHERE VName = 'MaxID'

WHILE(1=1)
BEGIN
	UPDATE TOP(4500) t SET t.CreatedDate = DATEADD(DAY, -1, GETDATE())
	FROM dbo.TOControl_Transition t WITH (ROWLOCK, UPDLOCK)
	WHERE t.ID <= @MaxID
		AND t.CreatedDate IS NULL

	IF @@ROWCOUNT = 0 
		BREAK
END

--TOControl_TicketDetails_Insert
DECLARE @MaxRowID_Ins BIGINT = 0
SELECT @MaxRowID_Ins = sValue
FROM dbo.TOControl_Tickets_Setting WITH (ROWLOCK)
WHERE sKey = 'TOControl_Insert'

WHILE(1=1)
BEGIN
	UPDATE TOP(4500) t SET t.CreatedDate = DATEADD(DAY, -1, GETDATE())
	FROM dbo.TOControl_TicketDetails_Insert t WITH (ROWLOCK, UPDLOCK)
	WHERE t.rowid <= @MaxRowID_Ins
		AND t.CreatedDate IS NULL

	IF @@ROWCOUNT = 0 
		BREAK
END

--TOControl_TicketDetails_Update 
DECLARE @MaxRowID_Upd BIGINT = 0
SELECT @MaxRowID_Upd = sValue
FROM dbo.TOControl_Tickets_Setting WITH (ROWLOCK)
WHERE sKey = 'TOControl_Update'

WHILE(1=1)
BEGIN
	UPDATE TOP(4500) t SET t.CreatedDate = DATEADD(DAY, -1, GETDATE())
	FROM dbo.TOControl_TicketDetails_Update t WITH (ROWLOCK, UPDLOCK)
	WHERE t.rowid <= @MaxRowID_Upd
		AND t.CreatedDate IS NULL

	IF @@ROWCOUNT = 0 
		BREAK
END

