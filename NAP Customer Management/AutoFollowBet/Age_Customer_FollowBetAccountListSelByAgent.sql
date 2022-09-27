/*<info serverAlias="DBCUST-CustDB" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Customer_FollowBetAccountListSelByAgent] 
	@DummyAgentID INT	
AS
/*
	Created: 20220912@Johnson
	Task: Get list follow bet accounts under dummy agent
	DB: DBCUST/CustDB
	
	Revisions:
		- 20220912@Johnson: initial sp [redmine: #176975]
	
	Paramter's Explanations:
				
*/
BEGIN
	SET NOCOUNT ON;
			
	SELECT c.custid, c.username, c.recommend as agentID, cf.DummyCustID, cf.DummyUsername
	FROM Acc_CustFollowBet cf WITH(NOLOCK)
		INNER JOIN customer c WITH(NOLOCK) ON cf.custid = c.custid
	WHERE cf.DummyAgentID = @DummyAgentID		
		AND cf.IsActive = 1
END	