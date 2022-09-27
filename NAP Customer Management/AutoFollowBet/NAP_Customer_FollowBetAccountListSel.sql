/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[NAP_Customer_FollowBetAccountListSel] 
	@username VARCHAR(50) = '',
	@currency TINYINT = 0,
	@site VARCHAR(10) = '',
	@DummyAgentID INT,	
	@isActive BIT = 1
AS
/*
	Created: 20220908@Johnson
	Task: Get list follow bet accounts 
	DB: DBCUST/CustDB
	
	Revisions:
		- 20220908@Johnson: initial sp [redmine: #176975]
	
	Paramter's Explanations:
				
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @_site VARCHAR(10) = NULLIF (@site,''),
			@_currency TINYINT = NULLIF(@currency,0)
	
	CREATE TABLE #Result (custid INT PRIMARY KEY, username VARCHAR(30), agentID INT, DummyCustID INT, DummyUsername VARCHAR(30), DummyAgentID INT, currency TINYINT, site VARCHAR(10), creator INT, createdDate DATETIME, isActive BIT)
	
	INSERT INTO #Result(custid, username, agentID, DummyCustID, DummyUsername, currency, site, creator, createdDate, isActive)
	SELECT c.custid, c.username, c.recommend as agentID, cf.DummyCustID, cf.DummyUsername, c.currency, c.site, cf.creator, cf.createdDate, cf.IsActive		
	FROM Acc_CustFollowBet cf WITH(NOLOCK)
		INNER JOIN customer c WITH(NOLOCK) ON cf.custid = c.custid
	WHERE cf.DummyAgentID = @DummyAgentID
		AND c.currency = ISNULL(@_currency,c.currency)
		AND c.site = ISNULL(@_site,c.site)
		AND 1 = CASE WHEN @username <> '' AND c.username LIKE @username + '%' THEN 1 
					WHEN @username = '' THEN 1
					ELSE 0 END
		AND cf.IsActive = @IsActive
			
	SELECT rs.custid, rs.username, c.username as Agent, DummyCustID, DummyUsername, e.currency, rs.site, creator.username as AddedBy, rs.createdDate, rs.isActive
	FROM #Result rs
		INNER JOIN customer c WITH(NOLOCK) ON rs.agentID = c.custid
		INNER JOIN customer creator WITH(NOLOCK) ON rs.creator = creator.custid
		INNER JOIN exchange e WITH(NOLOCK) ON rs.currency = e.exchangeid 
			
END