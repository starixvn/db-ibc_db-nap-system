/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
/*
Created: 20231127@Max
Task : Nap CM - Turnover Control - TO control service was running with a delay of approximately 1 hour [Redmine: #197464]
DB: DB052/DB053.bodb02
*/
USE bodb02
GO

--TOControl_Transition
WHILE(1=1)
BEGIN
	UPDATE TOP(4500) t SET t.CreatedDate = DATEADD(DAY, -1, GETDATE())
	FROM dbo.TOControl_Transition t WITH (ROWLOCK, UPDLOCK)
	WHERE t.CreatedDate IS NULL

	IF @@ROWCOUNT = 0 
		BREAK
END

--TOControl_TicketDetails_Insert
WHILE(1=1)
BEGIN
	UPDATE TOP(4500) t SET t.CreatedDate = DATEADD(DAY, -1, GETDATE())
	FROM dbo.TOControl_TicketDetails_Insert t WITH (ROWLOCK, UPDLOCK)
	WHERE t.CreatedDate IS NULL

	IF @@ROWCOUNT = 0 
		BREAK
END

--TOControl_TicketDetails_Update 
WHILE(1=1)
BEGIN
	UPDATE TOP(4500) t SET t.CreatedDate = DATEADD(DAY, -1, GETDATE())
	FROM dbo.TOControl_TicketDetails_Update t WITH (ROWLOCK, UPDLOCK)
	WHERE t.CreatedDate IS NULL

	IF @@ROWCOUNT = 0 
		BREAK
END

