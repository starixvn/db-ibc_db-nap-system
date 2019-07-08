/*<info serverAlias="DBAGE-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TASK_TOControl_DeleteOldTransition]
AS 
/*
Created: 20170324@Francis
Task : Delete old data for TOControl_Transition
DB: DBAGE.bodb02

Original:

Revisions:
	- 20190708@Patrick: Move to DB052 - [Redmine:97442]

Param explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MaxID BIGINT = 0

	SELECT @MaxID = CONVERT(BIGINT, VValue)
	FROM dbo.TOConTrol_GlobalVariables WITH (ROWLOCK)
	WHERE VName = 'MaxID'

	--Keep 10000 very first rows in the table
	IF @MaxID - 10000 <= 0
		RETURN

	SET @MaxID = @MaxID - 10000

	WHILE EXISTS (SELECT 1 FROM dbo.TOControl_Transition WITH (NOLOCK) WHERE ID < @MaxID) --To avoid TABLOCK escalation
		DELETE TOP (4500)
		FROM dbo.TOControl_Transition WITH (UPDLOCK, ROWLOCK)
		WHERE ID < @MaxID
END