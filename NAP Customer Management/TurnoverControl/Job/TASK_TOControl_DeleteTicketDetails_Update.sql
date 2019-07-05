/*<info serverAlias="DBAGE-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[TASK_TOControl_DeleteTicketDetails_Update] 
	@BatchSize INT = 4500
AS 
/*
	Created: 20190702@Patrick
	Task : Delete old data for DeleteTicketDetails_Update
	DB: DBAGE.bodb02
	Revisions:
		- 20190702@Patrick: Intial [Redmine: #112219]

	Param explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MaxID BIGINT = 0

	SELECT @MaxID = sValue
	FROM dbo.TOControl_Tickets_Setting WITH (ROWLOCK)
	WHERE sKey = 'TOControl_Update'

	--Keep 10000 very first rows in the table
	IF @MaxID - 10000 <= 0
	RETURN

	SET @MaxID = @MaxID - 10000

	WHILE EXISTS (
		SELECT TOP 1 1 FROM dbo.TOControl_TicketDetails_Update WITH (NOLOCK) 
		WHERE rowid < @MaxID
	) --To avoid TABLOCK escalation
	BEGIN
		DELETE TOP (@BatchSize)
		FROM dbo.TOControl_TicketDetails_Update WITH (UPDLOCK, ROWLOCK)
		WHERE rowid < @MaxID

		WAITFOR DELAY '00:00:00:100'
	END
END