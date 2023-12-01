/*<info serverAlias="DBAGE-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TASK_TOControl_DeleteOldTransition]
AS 
/*
Created: 20170324@Francis
Task : Delete old data for TOControl_Transition
DB: DBAGE.bodb02

Original:

Revisions:
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
	SELECT @MaxID = MAX(t.ID)
	FROM dbo.TOControl_Transition t WITH (NOLOCK)
	WHERE t.CreatedDate < @ArchiveDate

	
	WHILE EXISTS (SELECT 1 FROM dbo.TOControl_Transition WITH (NOLOCK) WHERE ID < @MaxID) --To avoid TABLOCK escalation
	BEGIN
		DELETE TOP (4500)
		FROM dbo.TOControl_Transition WITH (UPDLOCK, ROWLOCK)
		WHERE ID < @MaxID
	END

END