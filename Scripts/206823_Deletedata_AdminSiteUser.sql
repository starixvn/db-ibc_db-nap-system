/*<info serverAlias="DBPRO-bodb02 " executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20250205@Louisa
    Task: Delete redundant data
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20250205@Louisa: Delete redundant data [Redmine:#206823]
		
	Param's explanation:
		
*/
BEGIN
	DELETE FROM AdminSiteUser
	WHERE CustID = 203124888
END
GO