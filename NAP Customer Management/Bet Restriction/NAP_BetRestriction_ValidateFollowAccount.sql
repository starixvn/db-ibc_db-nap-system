/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_ValidateFollowAccount] (
	  @FollowAccount	NVARCHAR(50) = NULL
	 ,@FollowAccountID  INT = NULL OUTPUT
	 ,@Username NVARCHAR(50) = NULL
	 ,@ExchangeID INT = NULL
)
AS
/*
	Created: 20190815@Eden
	Task : Validate FollowAccount
	DB: DBCUST/CUSTDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]

	Example: 
	DECLARE @FollowAccountID INT
	EXEC NAP_BetRestriction_ValidateFollowAccount
		@FollowAccount = '8RM888',
		@FollowAccountID  = @FollowAccountID OUTPUT,
	SELECT @FollowAccountID 
	*/
BEGIN
	IF @Username IS NOT NULL
		SELECT @ExchangeID = currency
		FROM custinfo c WITH(NOLOCK) 
		WHERE username = @Username
	
	--> IF Smart Punter currency = UUS --> 8RM currency must be UUS 
	IF @ExchangeID = 20
	BEGIN
		SELECT @FollowAccountID = c.custid
		FROM  custinfo c WITH(NOLOCK) 
		WHERE username = @FollowAccount  AND currency = 20
	END
	ELSE --8RM account must be member of '8RM' agent
		SELECT @FollowAccountID = c.custid
		FROM custinfo c WITH(NOLOCK) 
			INNER JOIN custinfo rm WITH(NOLOCK) ON c.recommend = rm.custid
		WHERE rm.username = '8RM'
			AND c.username = @FollowAccount 
			AND c.roleid = 1
END
GO


