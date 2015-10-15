USE bodb02
GO
ALTER PROCEDURE [dbo].[NAP_ColossusBets_PayoutDetail]
(
	@BetId		BIGINT = 0
)
AS
/*
Created: 20151012@bobby.nguyen
Task : #44588 - Colossus Bets Payout Management
DB: DBTXN.bodb02
Original:
Revisions:
	- 20151012@bobby.nguyen: Initial
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT d.CreatedDate
		, ISNULL(c.UserName, '-') AS UserName
		, d.StatusId
		, d.PayStatus
		, d.PayNote
		, d.IP
		
	FROM dbo.PayoutDetail d WITH(NOLOCK)
		LEFT JOIN CustDB.dbo.customer c WITH(NOLOCK)
		ON d.CreatedBy = c.custid
	WHERE d.PayoutTransId = @BetId
		--AND c.roleid = 4
		
	ORDER BY d.CreatedDate DESC
	
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[NAP_ColossusBets_PayoutDetail] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_ColossusBets_PayoutDetail] TO [vnteam]
GO