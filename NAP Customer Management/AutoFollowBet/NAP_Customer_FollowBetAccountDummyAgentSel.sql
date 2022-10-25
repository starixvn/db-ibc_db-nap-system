/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[NAP_Customer_FollowBetAccountDummyAgentSel] 	
AS
/*
	Created: 20220909@Johnson
	Task: Get list dummy agents 
	DB: DBCUST/CustDB
	
	Revisions:
		- 20220909@Johnson: initial sp [redmine: #176975]
		- 20221025@Johnson: add more dummy agents [redmine:#179336]
	Paramter's Explanations:
				
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT custid, username
	FROM customer WITH(NOLOCK)
	WHERE username IN ('8RM8801','8RMTest01','8RM8802','8RM8803','8RM8804','8RM8805','8RM8806','8RM8807','8RM8808','8RM8809','8RM8810')
END	