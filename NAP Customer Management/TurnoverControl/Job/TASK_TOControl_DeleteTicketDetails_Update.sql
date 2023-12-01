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
		- 20231127@Max: Nap CM - Turnover Control - TO control service was running with a delay of approximately 1 hour [Redmine: #197464]

	Param explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MaxID BIGINT = 0
		,@ArchiveDate DATETIME

	SET @ArchiveDate = DATEADD(DAY, -3, GETDATE())

	--Keep data least 3 days
	SELECT @MaxID = MAX(t.rowid)
	FROM dbo.TOControl_TicketDetails_Update t WITH (NOLOCK)
	WHERE t.CreatedDate < @ArchiveDate

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