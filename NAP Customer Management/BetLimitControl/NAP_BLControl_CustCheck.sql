/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_CustCheck] 
	@Username VARCHAR(30) = NULL,
	@BetLimitTypeID INT = NULL,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(200) = '' OUTPUT,
	@CustID	INT = NULL OUTPUT,
	@site NVARCHAR(50) = NULL OUTPUT
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - Insert new CustSetting 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]
	- 20200922@Eden: BetLimitControl - Add multiple customers [RedmineID: #141767]
	- 20240725@Tacy: Remove linked-server/cross-db on NAP_UserControl [redmineID: #208402]

	Parameter explanation:
	- @ErrorCode: 
		1 - Invalid Username
		2 - The selected user has this bet limit type already.
		3 - Invalid Bet Limit Type. Please try again.

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(200) = '' 
	EXEC NAP_BLControl_CustCheck 
		@Username = 'member01',
		@BetLimitTypeID  = 1,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	SET NOCOUNT ON;

	SELECT @CustID = CustID 
	FROM  CustInfo WITH(NOLOCK)
	WHERE UserName = @UserName 
		  AND roleid IN (1,2,3,4)

	IF @CustID IS NULL
	BEGIN
		SELECT @ErrorCode = 1
			  ,@ErrorMsg = 'Invalid username.'

		RETURN
	END

	SELECT @site = c.Site
	FROM Customer c WITH(NOLOCK) 
	WHERE c.custid = @CustID
	
	IF EXISTS(  SELECT TOP 1 1 
				FROM BetLimitControlCustSetting WITH(NOLOCK)
				WHERE CustID = @CustID and BetLimitTypeID = @BetLimitTypeID )
	BEGIN
		SELECT @ErrorCode = 2
			  ,@ErrorMsg = 'The selected user(s) has this Bet Limit Type already.'
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