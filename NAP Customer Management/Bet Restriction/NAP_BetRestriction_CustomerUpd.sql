/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CustomerUpd] (
	  @CustID			INT
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
	Task : Update Bet Restriction for Customer
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]

	Parameter explanation:
	@ErrCode = :
			0 - succeed
			3 - Invalid 8RM Account.
			4 - This record no longer exists in the Bet Restriction List.

	Example: 
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_CustomerUpd
		@CustID = 15924397, 
		@UserID = 8,
		@LiveBetAccept = 6 , 
		@SeizeBetTicket = 40 , 
		@MaxBet = 200.00, 
		@MaxPerMatch = 2000.00, 
		@FollowAccount = '8RM888',
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT
	SELECT @ErrCode, @ErrMsg

	*/
BEGIN	
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31702
	DECLARE @site NVARCHAR(50)
	DECLARE @FollowAccountID INT
	DECLARE @LiveBetAccept_Old  SMALLINT, 
			@SeizeBetTicket_Old TINYINT, 
			@MaxBet_Old         MONEY, 
			@MaxPerMatch_Old    MONEY, 
			@FollowAccountID_Old  INT,
			@UserName	NVARCHAR(50),
			@FollowAccount_Old	NVARCHAR(50)

	SET @ErrCode = 0
	SET @StartRun = GETDATE()

	SELECT @LiveBetAccept_Old = LiveBetAccept, 
		   @SeizeBetTicket_Old = SeizeBetTicket, 
		   @MaxBet_Old = MaxBet, 
		   @MaxPerMatch_Old = MaxPerMatch, 
		   @FollowAccountID_Old = FollowAccount
	FROM BetRestriction_Customer WITH(NOLOCK)
	WHERE CustID = @CustID
		  AND SportType = @SportType;

	IF @@ROWCOUNT = 0
	BEGIN
		SET @ErrCode = 4
		SELECT @ErrMsg = 'This record no longer exists in the Bet Restriction List.'
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

	IF @MaxBet < 0 
	BEGIN
		SET @ErrCode = 5
		SELECT @ErrMsg = 'Invalid Max Bet amount.' 
		RETURN
	END

	IF @MaxPerMatch < 0
	BEGIN
		SET @ErrCode = 6
		SELECT @ErrMsg = 'Invalid Max Per Match amount.' 
		RETURN
	END

	SELECT @site = Site FROM Customer c WITH(NOLOCK) WHERE c.custid = @CustID
	
	IF	@LiveBetAccept_Old = @LiveBetAccept 
		AND ISNULL(@SeizeBetTicket_Old,0) = ISNULL(@SeizeBetTicket,0)
		AND ISNULL(@MaxBet_Old,-1) = ISNULL(@MaxBet,-1)
		AND ISNULL(@MaxPerMatch_Old,-1) = ISNULL(@MaxPerMatch,-1)
		AND ISNULL(@FollowAccountID_Old ,0)= ISNULL(@FollowAccountID,0)
	BEGIN
		SELECT @ErrMsg = N'No change'
		RETURN
	END

	SELECT @UserName = username FROM Customer WITH(NOLOCK) WHERE custid = @CustID
	SELECT @FollowAccount_Old = username FROM Customer WITH(NOLOCK) WHERE custid = @FollowAccountID_Old
	
	BEGIN TRY
		UPDATE BetRestriction_Customer WITH(ROWLOCK)
		SET LiveBetAccept = @LiveBetAccept, 
			SeizeBetTicket = @SeizeBetTicket, 
			MaxBet = @MaxBet, 
			MaxPerMatch = @MaxPerMatch, 
			FollowAccount = @FollowAccountID
		WHERE CustID = @CustID
			AND SportType = @SportType;  
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SELECT @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)
	SELECT  @LogDataNew = '<R '
						+ 'UserName="'+ coalesce(cast(@UserName as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAccept="'+ coalesce(cast(@LiveBetAccept as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicket="'+ coalesce(cast(@SeizeBetTicket as varchar(50)),space(1)) + '" ' 
						+ 'MaxBet="'+ coalesce(cast(@MaxBet as varchar(50)),space(1)) + '" ' 
						+ 'MaxPerMatch="'+ coalesce(cast(@MaxPerMatch as varchar(50)),space(1)) + '" ' 
						+ 'FollowAccount="'+ coalesce(cast(@FollowAccount as varchar(50)),space(1)) + '" '
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" ' 
						+ ' />',
			@LogDataOld = '<R '
						+ 'UserName="'+ coalesce(cast(@UserName as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAccept="'+ coalesce(cast(@LiveBetAccept_Old as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicket="'+ coalesce(cast(@SeizeBetTicket_Old as varchar(50)),space(1)) + '" ' 
						+ 'MaxBet="'+ coalesce(cast(@MaxBet_Old as varchar(50)),space(1)) + '" ' 
						+ 'MaxPerMatch="'+ coalesce(cast(@MaxPerMatch_Old as varchar(50)),space(1)) + '" ' 
						+ 'FollowAccount="'+ coalesce(cast(@FollowAccount_Old as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />'
		

	IF @site = 'CN88'
	BEGIN
		EXEC dbo.CS_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionID,
			@TrackingValue		= @LogDataNew,
			@TrackingValue2		= @LogDataOld,
			@Duration			= @Duration
	END
	ELSE -- MBC
	BEGIN
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionID,
			@TrackingValue		= @LogDataNew,
			@TrackingValue2		= @LogDataOld,
			@Duration			= @Duration
	END	                     
END
GO


