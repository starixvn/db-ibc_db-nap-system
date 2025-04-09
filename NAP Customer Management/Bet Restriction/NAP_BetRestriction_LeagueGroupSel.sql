/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_BetRestriction_LeagueGroupSel] 
@SportType SMALLINT
AS  
/*  
 Created: 20230302@Helios  
 Task : Get League Group in DropDownList Add/Edit Account
 DB: DBACC/bodb02  
 Original:  
  
 Revisions:    
 - 20230302@Helios: Create New SP  [RedmineID: #183663]  
 - 20250327@Winfred: [NAP CM] Customer - Bet Restriction - E-Sports [Redmine: #221607]
  
 Example:   
 EXEC NAP_BetRestriction_LeagueGroupSel 1 
  
   
 */  
BEGIN  
  SELECT GroupID , GroupName
  FROM dbo.LeagueGroup WITH(NOLOCK)  
  WHERE SportType IN (0,@SportType)					-- SportType = 0 is Show ALL Sport
END  