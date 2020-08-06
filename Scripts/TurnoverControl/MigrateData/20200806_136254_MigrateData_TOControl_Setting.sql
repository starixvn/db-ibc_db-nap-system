/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
/*
	create: @Max
	Task: Migrate old data TO Control [Redmine: #136254]
	DB: DBCUST/CUSTDB
*/

CREATE TABLE #match (matchid INT)
INSERT INTO #match (matchid)
SELECT matchid
FROM DBAGE.bodb02.dbo.match with (nolock)
WHERE eventstatus <> 'completed' and sporttype < 99

UPDATE s
	SET IsEventLockTOLimit = CASE WHEN IsEventLockTOLimit IS NULL THEN 0 ELSE IsEventLockTOLimit END
		, IsGlobalLockTOLimit = CASE WHEN IsGlobalLockTOLimit IS NULL THEN 0 ELSE IsGlobalLockTOLimit END
FROM TOControl_Setting s with(ROWLOCK)
	INNER JOIN #match m on s.matchid = m.matchid
WHERE IsEventLockTOLimit IS NULL OR IsGlobalLockTOLimit IS NULL