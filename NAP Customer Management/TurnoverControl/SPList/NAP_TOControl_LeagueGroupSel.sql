/*<info serverAlias="DBAGE-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_LeagueGroupSel]
AS
/*
	Created: 20251114@Johnson	
	Task: Get league group
	DB: DBAGE.bodb02

	Revisions:
		- 20251114@Johnson: TO Monitor Control By League Group [Redmine: 243977]

	Parameter's explaination:
	
*/
BEGIN
    SET NOCOUNT ON;

    SELECT GroupID, GroupName ,SportType
    FROM LeagueGroup WITH(NOLOCK)
    WHERE SportType IN (0, @SportType) AND GroupID NOT IN (42, 74, 108)
    ORDER BY GroupID ASC
END