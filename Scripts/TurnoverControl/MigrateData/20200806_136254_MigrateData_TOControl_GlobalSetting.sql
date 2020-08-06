/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
/*
	create: @Max
	Task: Migrate old data TO Control [Redmine: #136254]
	DB: DBCUST/CUSTDB
*/

WHILE 1=1
BEGIN
	UPDATE TOP(2000) s
	SET  IsGlobalLockTOLimit = CASE WHEN IsGlobalLockTOLimit IS NULL THEN 0 ELSE IsGlobalLockTOLimit END
	FROM TOControl_GlobalSetting s with(ROWLOCK)
	WHERE IsGlobalLockTOLimit IS NULL
	
	IF @@ROWCOUNT = 0 BREAK
END
