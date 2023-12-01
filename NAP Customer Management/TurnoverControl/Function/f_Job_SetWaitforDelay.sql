/*<info serverAlias="DBCUST-CUSTDB" executers="" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_Job_SetWaitforDelay] ()
RETURNS VARCHAR(100)
/* 
	Created:20210601@July
    Task: 
    DB: DBCUST/CUSTDB
    
	Revisions:
		- 20210601@July: support deploy without UM - [Redmine:130912]
		- 20211221@July: Turn off - [Redmine: #166411]
		- 20231201@Max: Nap CM - Turnover Control - TO control service was running with a delay of approximately 1 hour [Redmine: #197464]
	Notes:
		DECLARE @Delay VARCHAR(100) = ''
		SET @Delay = dbo.f_Job_SetWaitforDelay () 
		WAITFOR DELAY @Delay

*/
AS
BEGIN
    RETURN '00:00:10:000'
END
GO
