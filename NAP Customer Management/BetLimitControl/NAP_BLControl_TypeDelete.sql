/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_TypeDelete] 
	@BetLimitTypeID INT,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(100) = '' OUTPUT 
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - Remove Type 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:
	- @LiveIndicator : 0 : NonLive , 1: Live , 2 : Both, 3 : All
	- @ErrorCode: 
		1: The bet limit type is no longer exists.

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(100) = '' 
	EXEC NAP_BLControl_TypeDelete 
		@BetLimitTypeID = 1,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	IF NOT EXISTS( SELECT TOP 1 1 FROM BetLimitControlType t WITH(NOLOCK) WHERE t.BetLimitTypeID = @BetLimitTypeID )
	BEGIN
		SELECT @ErrorCode = 1 ,
			@ErrorMsg = 'The bet limit type is no longer exists.'

		RETURN
	END

	DELETE 
	FROM BetLimitControlTypeDetail WITH(ROWLOCK,UPDLOCK)
	WHERE BetLimitTypeID = @BetLimitTypeID

	DELETE 
	FROM BetLimitControlType WITH(ROWLOCK,UPDLOCK)
	WHERE BetLimitTypeID = @BetLimitTypeID
END
GO


