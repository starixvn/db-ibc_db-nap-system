/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[NAP_Customer_FollowBetAccountDummyAgentSel] 	
AS
/*
	Created: 20220909@Johnson
	Task: Get list dummy agents 
	DB: DBCUST/CustDB
	
	Revisions:
		- 20220909@Johnson: initial sp [redmine: #176975]
	
	Paramter's Explanations:
				
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT custid, username
	FROM customer WITH(NOLOCK)
	WHERE username IN ('8RM8801','8RMTest01')
END	