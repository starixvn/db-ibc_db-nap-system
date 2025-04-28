/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CustomerIns] (
	  @UserName				NVARCHAR(50)
	 ,@UserId				INT
	 ,@IP					VARCHAR(15) = ''
	 ,@SportType			SMALLINT = 1
	 ,@LiveBetAccept		SMALLINT = NULL
	 ,@SeizeBetTicket		TINYINT = NULL
	 ,@MaxBet				MONEY = NULL
	 ,@MaxPerMatch			MONEY = NULL
	 ,@LeastStake			MONEY = NULL	-- Add New Param #223442
	 ,@FollowAccount		NVARCHAR(50) = NULL
	 ,@AccumulateBalance	BIT = 0
	 ,@ErrMsg				NVARCHAR(MAX) = '' OUTPUT	
	 ,@ErrCode				TINYINT = 0 OUTPUT
	 ,@LeagueGroupID		VARCHAR(4000) = NULL  -- Add New Param #183663
)
AS 
/*
	Created: 20190815@Eden
	Task : Insert Bet Restriction for Customer
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]
	- 20230303@Helios: Add Column LeagueGroupID -  ADD LOG LeagueGroupID - Change Position DataLog [RedmineID: #183663]
	- 20230613@Luke: Option to apply Seize Bet if reach risk balance [Redmine: #187771]
	- 20240911@Johnson: Apply Inhouse for BLC [redmine:#209892]
	- 20250428@Logan: Basketball - AddcTicket Stake [redmine:#223442]
	Parameter explanation:
	@ErrCode = :
			0 - succeed
			1 - Invalid Username
			2 - <Username> has already exists in the Bet Restriction list.
			3 - Invalid 8RM Account.
	@LeagueGroupID = :
			ALL : Selected ALL
			NULL : Selected None
			1,2,3,4... : Selected League

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
		@LeastStake	= 2000.00	-- Add New Param #223442
		@FollowAccount = '8RM888',
		@AccumulateBalance = 0,
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT,
        @LeagueGroupID = '2,4,6,8,12,22,55'

	SELECT @ErrCode, @ErrMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31701
	DECLARE @site  NVARCHAR(50)
	DECLARE @FollowAccountID INT, @CustID INT , @LeagueGroupName VARCHAR(4000)

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
							  WHEN @ErrCode = 2 THEN @UserName + ' has already existed in the Bet Restriction list.'  
						 END
		RETURN
	END

	EXEC NAP_BetRestriction_ValidateFollowAccount
		@FollowAccount = @FollowAccount,
		@FollowAccountID  = @FollowAccountID OUTPUT,
		@Username = @UserName

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
	
	BEGIN TRY
		INSERT INTO BetRestriction_Customer(
			CustID, 
			SportType, 
			LiveBetAccept, 
			SeizeBetTicket, 
			MaxBet, 
			MaxPerMatch, 
			FollowAccount,
			AccumulateBalance,
			LeagueGroupID,    -- Add new Column #183663
			RepUpdateTime, 
			LeastStake	-- Add New Column #223442
		   )
		SELECT  @CustID, 
				@SportType, 
				@LiveBetAccept, 
				@SeizeBetTicket, 
				@MaxBet, 
				@MaxPerMatch, 
				@FollowAccountID,
				@AccumulateBalance,
				CASE WHEN @LeagueGroupID IS NULL THEN NULL ELSE @LeagueGroupID END,  -- Add new Column #183663
				dbo.f_GetDateTime2(),
				@LeastStake              -- Add New Param #223442
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SELECT @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)


	SELECT @LeagueGroupName = CASE 
								WHEN @LeagueGroupID IS NULL THEN ''
								WHEN @LeagueGroupID = 'All' THEN 'All'
								ELSE
									STUFF ((SELECT ', ' + lg.GroupName
									FROM DBACC.bodb02.dbo.LeagueGroup lg WITH (NOLOCK)
									INNER JOIN STRING_SPLIT (@LeagueGroupID , ',') AS t ON t.value = lg.GroupID
									FOR XML PATH('')), 1, 1, '')
							  END

	DECLARE @LogDataNew VARCHAR(4000)
	SELECT  @LogDataNew = '<R '
						+ 'UserName="'+ COALESCE(CAST(@UserName AS VARCHAR(50)),SPACE(1)) + '" ' 
						+ 'LBA="'+ COALESCE(CAST(@LiveBetAccept AS VARCHAR(50)),'FUL') + '" '
						+ 'SBT="'+ CASE WHEN @SeizeBetTicket IS NULL THEN 'FUL' WHEN @SeizeBetTicket = 0 THEN 'None' ELSE CAST(@SeizeBetTicket AS VARCHAR(50)) END  + '" '   
						+ 'LeagueGroupName="'+ coalesce(cast(@LeagueGroupName as varchar(4000)) , space(1)) + '" '  -- Add new LogChanged #183663
						+ 'FA="'+ coalesce(cast(@FollowAccount as varchar(50)),space(1)) + '" '
						+ 'AB="'+ CASE WHEN ISNULL(@AccumulateBalance,0) = 0 THEN 'No' ELSE 'Yes' END + '" '
						+ 'maxb="'+ coalesce(cast(@MaxBet as varchar(50)),space(1)) + '" ' 
						+ 'mpm="'+ coalesce(cast(@MaxPerMatch as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
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


