/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_DefaultSetting_SMACheck] 
	@Username VARCHAR(30) = NULL,
	@BetLimitTypeID INT = NULL,
	@CustID	INT = NULL OUTPUT,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20200818@Eden
	Task : Check SMA Username for Bet Limit control default setting config
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200818@Eden: Create New SP  [RedmineID: #139701]

	Parameter explanation:

	Examples:
		DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(200) = '', @CustID INT 
		EXEC NAP_BLControl_DefaultSetting_SMACheck 
			@Username = 'agent01',
			@BetLimitTypeID  = 2,
			@CustID = @CustID OUTPUT,
			@ErrorCode = @ErrorCode OUTPUT,
			@ErrorMsg = @ErrorMsg OUTPUT
		SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	-- Check SMA
	SELECT @CustID = CustID 
	FROM  CustInfo WITH(NOLOCK)
	WHERE UserName = @UserName 
		  AND roleid IN (2,3,4)

	IF @CustID IS NULL
	BEGIN
		SELECT @ErrorCode = 1
			  ,@ErrorMsg = 'Invalid username.'

		RETURN
	END

	IF EXISTS(  SELECT TOP 1 1 
				FROM BetLimitControlDefaultSetting WITH(NOLOCK)
				WHERE CustID = @CustID and BetLimitTypeID = @BetLimitTypeID )
	BEGIN
		SELECT @ErrorCode = 2
			  ,@ErrorMsg = 'The selected account has already had Default Bet Limit Setting for the selected Bet Limit Type. Please edit the setting instead of creating a new one.'
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


