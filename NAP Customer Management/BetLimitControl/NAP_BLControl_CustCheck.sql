/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_CustCheck] 
	@Username VARCHAR(30) = NULL,
	@BetLimitTypeID INT = NULL,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(MAX) = '' OUTPUT,
	@CustID	INT = NULL OUTPUT
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - Insert new CustSetting 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:
	- @ErrorCode: 
		1 - Invalid Username
		2 - The selected user has this bet limit type already.
		3 - Invalid Bet Limit Type. Please try again.

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(MAX) = '' 
	EXEC NAP_BLControl_CustCheck 
		@Username = 'member01',
		@BetLimitTypeID  = 1,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	SET @ErrorCode = 0

	SELECT @CustID = CustID 
	FROM  CustInfo WITH(NOLOCK)
	WHERE UserName = @UserName 
		  AND roleid IN (1,2,3,4)

	IF @CustID IS NULL
	BEGIN
		SELECT @ErrorCode = 1
			  ,@ErrorMsg = 'Invalid Username'

		RETURN
	END

	IF EXISTS(  SELECT TOP 1 1 
				FROM BetLimitControlCustSetting WITH(NOLOCK)
				WHERE CustID = @CustID and BetLimitTypeID = @BetLimitTypeID )
	BEGIN
		SELECT @ErrorCode = 2
			  ,@ErrorMsg = 'The selected user has this bet limit type already.'
		RETURN
	END

	IF NOT EXISTS( SELECT TOP 1 1 FROM BetLimitControlType t WITH(NOLOCK) WHERE BetLimitTypeID = @BetLimitTypeID )
	BEGIN
		SELECT @ErrorCode = 3 ,
			@ErrorMsg = 'Invalid Bet Limit Type. Please try again.'
		RETURN
	END
END
GO


