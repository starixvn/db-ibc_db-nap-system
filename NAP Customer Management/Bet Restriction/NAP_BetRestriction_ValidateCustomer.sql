/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_ValidateCustomer] (
	  @UserName			NVARCHAR(50) = NULL
	 ,@SportType		TINYINT = 1
	 ,@ErrCode			TINYINT = 0 OUTPUT
	 ,@CustID			INT = NULL OUTPUT
)
AS
/*
	Created: 20190815@Eden
	Task : Validate UserName ,FollowAccount
	DB: DBCUST/CUSTDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]

	Parameter explanation:
	@ErrCode = :
			0 : succeed , can be inserted/Update
			1 - Invalid Username
			2 - <Username> has already exists in the Bet Restriction list.

	Example: 
	DECLARE @ErrCode INT , @CustID INT
	EXEC NAP_BetRestriction_ValidateCustomer
		@UserName = 'supertest01', 
		@SportType = 1,
		@ActionType = 1,
		@ErrCode  = @ErrCode OUTPUT,
		@CustID  = @CustID OUTPUT
	SELECT  @ErrCode ,@CustID
	*/
BEGIN
	SET @ErrCode = 0

	SELECT @CustID = CustID 
	FROM  CustInfo WITH(NOLOCK)
	WHERE UserName = @UserName 

	SET @ErrCode = 0

	IF @CustID IS NULL
	BEGIN
		SET @ErrCode = 1
		RETURN
	END

	IF EXISTS(  SELECT TOP 1 1 
				FROM BetRestriction_Customer WITH(NOLOCK)
				WHERE CustID = @CustID and SportType = @SportType )
	BEGIN
		SET @ErrCode = 2 
		RETURN
	END
END
GO


