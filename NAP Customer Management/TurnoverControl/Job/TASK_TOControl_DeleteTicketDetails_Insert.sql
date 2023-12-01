/*<info serverAlias="DBAGE-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TASK_TOControl_DeleteTicketDetails_Insert]
AS 
/*
	Created: 20180629@Helen
	Task : Delete old data for TOControl_TicketDetails_Insert
	DB: DBAGE.bodb02

	Original:

	Revisions:
		- 20180629@Helen: Delete old data for TOControl_TicketDetails_Insert - [Redmine:97442]
		- 20190708@Patrick: Move to DB052 - [Redmine:#112219]
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
	FROM dbo.TOControl_TicketDetails_Insert t WITH (NOLOCK)
	WHERE t.CreatedDate < @ArchiveDate

	WHILE EXISTS (SELECT 1 FROM dbo.TOControl_TicketDetails_Insert WITH (NOLOCK) WHERE rowid < @MaxID) --To avoid TABLOCK escalation
	BEGIN
		DELETE TOP (4500)
		FROM dbo.TOControl_TicketDetails_Insert WITH (UPDLOCK, ROWLOCK)
		WHERE rowid < @MaxID
	END

END
GO