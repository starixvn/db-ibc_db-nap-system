/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CustomerIns] (
	  @UserName			NVARCHAR(50)
	 ,@UserId			INT
	 ,@IP				VARCHAR(15) = ''
	 ,@SportType		SMALLINT = 1
	 ,@LiveBetAccept	SMALLINT
	 ,@SeizeBetTicket	TINYINT = NULL
	 ,@MaxBet			MONEY = NULL
	 ,@MaxPerMatch		MONEY = NULL
	 ,@FollowAccount	NVARCHAR(50) = NULL
	 ,@ErrMsg			NVARCHAR(MAX) = '' OUTPUT	
	 ,@ErrCode			TINYINT = 0 OUTPUT
)
AS
/*
	Created: 20190815@Eden
	Task : Insert Bet Restriction for Customer
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]

	
	Parameter explanation:
	@ErrCode = :
			0 - succeed
			1 - Invalid Username
			2 - <Username> has already exists in the Bet Restriction list.
			3 - Invalid 8RM Account.

	Example: 
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_CustomerIns
		@UserName = 'supertest110',
		@UserId =8,
		@SportType = 1,
		@LiveBetAccept = -5 , 
		@SeizeBetTicket = 50 , 
		@MaxBet = 100.00, 
		@MaxPerMatch = 1000.00, 
		@FollowAccount = '8RM888',
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT
	SELECT @ErrCode, @ErrMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31701
	DECLARE @site  NVARCHAR(50)
	DECLARE @FollowAccountID INT, @CustID INT

	SET @ErrCode = 0
	SET @StartRun = GETDATE()

	EXEC dbo.NAP_BetRestriction_ValidateCustomer
		@UserName = @UserName, 
		@SportType = @SportType,
		@ErrCode  = @ErrCode OUTPUT,
		@CustID  = @CustID OUTPUT

	IF @ErrCode > 0
	BEGIN
		SELECT @ErrMsg = CASE WHEN @ErrCode = 1 THEN 'Invalid Username.'  
							  WHEN @ErrCode = 2 THEN @UserName + ' has already exists in the Bet Restriction list.'  
						 END
		RETURN
	END

	EXEC NAP_BetRestriction_ValidateFollowAccount
		@FollowAccount = @FollowAccount,
		@FollowAccountID  = @FollowAccountID OUTPUT

	IF @FollowAccount IS NOT NULL AND @FollowAccountID IS NULL
	BEGIN
		SET @ErrCode = 3
		SELECT @ErrMsg = 'Invalid 8RM Account.' 
		RETURN
	END

	SELECT @site = Site FROM Customer c WITH(NOLOCK) WHERE c.custid = @CustID
	
	BEGIN TRY
		INSERT INTO BetRestriction_Customer(
			CustID, 
			SportType, 
			LiveBetAccept, 
			SeizeBetTicket, 
			MaxBet, 
			MaxPerMatch, 
			FollowAccount
		   )
		SELECT  @CustID, 
				@SportType, 
				@LiveBetAccept, 
				@SeizeBetTicket, 
				@MaxBet, 
				@MaxPerMatch, 
				@FollowAccountID
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SELECT @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @LogDataNew VARCHAR(500)
	SELECT  @LogDataNew = '<R'
						+ 'UserName="'+ coalesce(cast(@UserName as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAccept="'+ coalesce(cast(@LiveBetAccept as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicket="'+ coalesce(cast(@SeizeBetTicket as varchar(50)),space(1)) + '" ' 
						+ 'MaxBet="'+ coalesce(cast(@MaxBet as varchar(50)),space(1)) + '" ' 
						+ 'MaxPerMatch="'+ coalesce(cast(@MaxPerMatch as varchar(50)),space(1)) + '" ' 
						+ 'FollowAccount="'+ coalesce(cast(@FollowAccount as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />'

	IF @site = 'CN88'
	BEGIN
		EXEC dbo.CS_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionID,
			@TrackingValue		= @LogDataNew,
			@Duration			= @Duration
	END
	ELSE -- MBC
	BEGIN
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionID,
			@TrackingValue		= @LogDataNew,
			@Duration			= @Duration
	END

END
GO


