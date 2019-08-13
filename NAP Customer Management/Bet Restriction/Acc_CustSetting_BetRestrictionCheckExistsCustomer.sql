/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCheckExistsCustomer] (
	  @UserName			NVARCHAR(100)
	 ,@SportType		TINYINT = 1
	 ,@IsAllowInsert	BIT = 0 OUTPUT
	 ,@MessageCode      INT = 0 OUTPUT
)
AS
/*
	Created: 20190809@Eden
	Task : Check exists Bet Restriction Customer
	DB: DBCUST/CustDB
	Original:

	Parameter definition:
	@MessageCode = :
			1 - Invalid Username
			2 - <Username> has already exists in the Bet Restriction list.
			IF @IsAllowInsert = 1 @MessageCode = CustID

	Example: 
	DECLARE @IsAllowInsert BIT, @MessageCode INT
	EXEC Acc_CustSetting_BetRestrictionCheckExistsCustomer
		@UserName = 'SuperTest11', 
		@IsAllowInsert = @IsAllowInsert OUTPUT,
		@MessageCode  = @MessageCode OUTPUT
	SELECT @IsAllowInsert, @MessageCode
	*/
BEGIN
	DECLARE @CustID	INT
	SET @IsAllowInsert = 1

	SELECT @CustID = CustID 
	FROM  CustInfo WITH(NOLOCK)
	WHERE UserName = @UserName 

	SET @MessageCode = @CustID

	IF @CustID IS NULL
	BEGIN
		SET @IsAllowInsert = 0 
		SET @MessageCode = 1
		RETURN
	END

	IF EXISTS(  SELECT TOP 1 1 
				FROM BetRestriction_Customer WITH(NOLOCK)
				WHERE CustID = @CustID and SportType = @SportType )
	BEGIN
		SET @IsAllowInsert = 0  
		SET @MessageCode = 2 
	END
END
GO


