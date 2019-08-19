/*<info serverAlias="DBACC-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_BetRestrictionSettingSel](
	@RestrictionLevel VARCHAR(30),
	@IsTest BIT
) 
RETURNS TABLE
AS

/*
    Created: 20190819@Eden
	Task : Get Bet Restriction Setting 
	DB: DBACC/bodb02
	Original:

	Revisions:  
	- 20190819@Eden: Create New SP  [RedmineID: #117727]

	Example: 
	select * from dbo.f_BetRestrictionSettingSel('BetRestriction_Site',0) 
    
*/
RETURN (  
	SELECT DISTINCT SportType,
		   IsShowData = CASE WHEN BackEndStatus <=  @IsTest THEN 1 ELSE 0 END
	FROM  BetRestriction_Setting WITH (NOLOCK)
	WHERE RestrictionLevel = @RestrictionLevel
)
GO
