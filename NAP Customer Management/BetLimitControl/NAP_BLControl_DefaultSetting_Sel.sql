/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_DefaultSetting_Sel] 
	@BetLimitTypeID INT = 0,
	@Username VARCHAR(30) = NULL,
	@UserId INT = 0,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20200818@Eden
	Task : get Bet Limit control default setting config
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200818@Eden: Create New SP  [RedmineID: #139701]

	Parameter explanation:
	Examples: EXEC [NAP_BLControl_DefaultSetting_Sel]
		@BetLimitTypeID = 0,
		@Username = '',
		@UserId = 8

	*/
BEGIN
	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey='CustomerManagement',
		@FunctionKey='DefaultBetLimitforNewMember',
		@Policy=1,
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		RETURN

	SELECT  t.BetLimitType,
			c.username,
			[Level] = CASE WHEN c.roleid = 2 THEN 'Agent'
						WHEN c.roleid = 3 THEN 'Master'
						WHEN c.roleid = 4 THEN 'Super'
					 END,
			e.currency,
			d.MaxBet,
			d.MaxPerMatch,
			c.custid,
			d.BetLimitTypeID
	FROM BetLimitControlDefaultSetting d WITH(NOLOCK)
		INNER JOIN BetLimitControlType t WITH(NOLOCK) ON d.BetLimitTypeID = t.BetLimitTypeID
		INNER JOIN customer c WITH(NOLOCK) on d.CustID = c.CustID
		INNER JOIN exchange e WITH(NOLOCK) ON c.currency = e.exchangeid
	WHERE c.username = CASE WHEN ISNULL(@Username,'') <> ''  THEN @Username  ELSE c.username END
		AND d.BetLimitTypeID = CASE WHEN ISNULL(@BetLimitTypeID,0) <> 0 THEN @BetLimitTypeID ELSE d.BetLimitTypeID END
	ORDER BY t.BetLimitType,c.username
END
GO


