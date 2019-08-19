/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_ValidateCustomer] (
	  @UserName			NVARCHAR(100)
	 ,@SportType		TINYINT = 1
	 ,@FollowAccount	NVARCHAR(100) = NULL
	 ,@IsAllowInsert	BIT = 0 OUTPUT
	 ,@MessageCode      INT = 0 OUTPUT
)
AS
/*
	Created: 20190815@Eden
	Task : Check exists Bet Restriction Customer
	DB: DBACC/bodb02
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]

	Parameter explanation:
	@IsAllowInsert =: 
			0 : Validate failed 
			1 : succeed , can be inserted
	@MessageCode = :
			1 - Invalid Username
			2 - <Username> has already exists in the Bet Restriction list.
			3 - Invalid FollowAccount 
			IF @IsAllowInsert = 1 @MessageCode = CustID (CustID will be inserted to BetRestriction_Customer)

	Example: 
	DECLARE @IsAllowInsert BIT, @MessageCode INT
	EXEC NAP_BetRestriction_ValidateCustomer
		@UserName = '12BETACCSD$01', @SportType = 1,
		@FollowAccount = '8RM888',
		@IsAllowInsert = @IsAllowInsert OUTPUT,
		@MessageCode  = @MessageCode OUTPUT
	SELECT @IsAllowInsert, @MessageCode
	*/
BEGIN
	DECLARE @CustID	INT
	SET @IsAllowInsert = 1
	SET @MessageCode = 0

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
		RETURN
	END

	IF @FollowAccount IS NOT NULL 
		AND NOT EXISTS(	SELECT TOP 1 1 
						FROM custinfo c WITH(NOLOCK) 
							INNER JOIN custinfo rm WITH(NOLOCK) ON c.recommend = rm.custid
						WHERE rm.username = '8RM'
							AND c.username = @FollowAccount 
							AND c.roleid = 1)
	BEGIN
		SET @IsAllowInsert = 0  
		SET @MessageCode = 3
		RETURN
	END
END
GO


