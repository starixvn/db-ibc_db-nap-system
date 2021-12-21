/*<info serverAlias="DBCUST-CUSTDB" executers="" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_Job_SetWaitforDelay] ()
RETURNS VARCHAR(100)
/* 
	Created:20210601@July
    Task: 
    DB: DBCUST/CUSTDB
    
	Revisions:
		- 20210601@July: support deploy without UM - [Redmine:130912]
		- 20211221@July: Turn on - [Redmine: #166411]
	Notes:
		DECLARE @Delay VARCHAR(100) = ''
		SET @Delay = dbo.f_Job_SetWaitforDelay () 
		WAITFOR DELAY @Delay

*/
AS
BEGIN
    RETURN '00:05:00:000'
END
GO
