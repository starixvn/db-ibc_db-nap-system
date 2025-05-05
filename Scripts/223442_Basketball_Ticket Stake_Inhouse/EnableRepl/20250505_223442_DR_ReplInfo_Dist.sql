/*<info serverAlias="DBCUST-CustDB" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250505@Logan	
	Task: In-House
	DB: DBCUST-CustDB
	
	Revisions:
		- 20250505@Logan: Created [RedmineID: #223442]

	Example:			
*/
IF EXISTS (SELECT * FROM dbo.RepInfo WITH (NOLOCK) WHERE [name] = 'BetRestriction_Customer')
BEGIN
	UPDATE RepInfo
	SET active = 1
	WHERE [group] = 0
		AND [name] =  'BetRestriction_Customer'
END
ELSE
BEGIN  
	SELECT 'BetRestriction_Customer not exists !!!'
END
GO
/***************************************************************************/
