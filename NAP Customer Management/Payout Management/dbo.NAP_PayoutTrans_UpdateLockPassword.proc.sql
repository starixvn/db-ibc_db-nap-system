/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO
ALTER PROCEDURE [dbo].[NAP_PayoutTrans_UpdateLockPassword]
(
	@CustId			INT
	, @ProductId	TINYINT
	, @Status		BIT
)
AS
/*
Created: 20160106@bobby.nguyen
Task : #50364 - Update for CB change request
DB: DBTXN.bodb02
Original:
Revisions:
	- 20160106@bobby.nguyen: Initial - Check for updating member locking pwd
	- 20180104@Paul: Add new status [Cancelled] for RNG Casino [RedmineID #88709]

Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;
	--check for still running payout trans
	IF(	NOT EXISTS (
			SELECT 1 
			FROM dbo.PayoutTrans (NOLOCK) 
			WHERE CustID = @CustId 
				AND ProductId = @ProductId
				AND PayoutStatusId NOT IN  (4, 5, 6)--('Completed', 'Expired', 'Cancelled') 
		)
	) 
	BEGIN
		EXEC [DBCUST].[CustDB].[dbo].[Dot_Member_UpdateLockPassword] @CustID = @custId, @status = 0
	END
	RETURN;
END
GO