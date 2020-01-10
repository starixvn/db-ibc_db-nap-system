/*<info serverAlias="DBAGE-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE [bodb02]
GO
ALTER PROCEDURE [dbo].[TASK_TOControl_GetTransition]
	@RowId BIGINT
AS 
/*
Created: 20170324@Francis
Task : Get data to sync to DBCUST
DB: DBAGE.bodb02

Original:

Revisions:
	- 20170920@Helen: TO Control Phase 3 - [Redmine: 75557]
	- 20190708@Patrick: Move to DB052 [Redmine: #112219]
	- 20191231@Malcolm: Separate setting and notification into Live/Non-Live and bettypes - [Redmine: #126348]

Param explanation:
*/
BEGIN
	SET NOCOUNT ON

	SELECT TOP (4500) t.ID AS RowId, t.CustID, t.matchid
		, t.adjusted_TurnOver, t.adjusted_HouseTurnOver
		,t.IsGroupHeadline, m.sporttype
		,t.liveindicator, t.bettypeID
	FROM dbo.TOControl_Transition t WITH (ROWLOCK)
		INNER JOIN dbo.match m WITH (NOLOCK) ON t.matchid = m.matchid
	WHERE t.ID > @RowId
	ORDER BY t.ID ASC
END