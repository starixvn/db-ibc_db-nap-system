/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CustomerUpd] (
	  @CustID				INT
	 ,@UserId				INT
	 ,@IP					VARCHAR(15) = ''
	 ,@SportType			SMALLINT = 1
	 ,@LiveBetAccept		SMALLINT = NULL
	 ,@SeizeBetTicket		TINYINT = NULL
	 ,@MaxBet				MONEY = NULL
	 ,@MaxPerMatch			MONEY = NULL
	 ,@FollowAccount		NVARCHAR(50) = NULL
	 ,@AccumulateBalance	BIT = 0
	 ,@ErrMsg				NVARCHAR(MAX) = '' OUTPUT
	 ,@ErrCode				TINYINT = 0 OUTPUT
	 ,@LeagueGroupID		VARCHAR(4000) = NULL -- Add New Param #183663
	 ,@LeastStake			MONEY = NULL	-- Add New Param #223442
)
AS
/*
	Created: 20190815@Eden
	Task : Update Bet Restriction for Customer
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]
	- 20230306@Helios: Update LeagueGroupID -  ADD LOG LeagueGroupID - Change Position DataLog [RedmineID: #183663]
	- 20240911@Johnson: Apply Inhouse for BLC [redmine:#209892]
	- 20250428@Logan: Basketball - AddcTicket Stake [redmine:#223442]
	Parameter explanation:
	@ErrCode = :
			0 - succeed
			3 - Invalid 8RM Account.
			4 - This record no longer exists in the Bet Restriction List.
	@LeagueGroupID = :
			ALL : Selected ALL
			NULL : Selected None
			1,2,3,4... : Selected League

	Example: 
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_CustomerUpd
		@CustID = 15924397, 
		@UserID = 8,
		@LiveBetAccept = 6 , 
		@SeizeBetTicket = 40 , 
		@MaxBet = 200.00, 
		@MaxPerMatch = 2000.00, 
		@LeastStake	= 2000.00	-- Add New Param #223442
		@FollowAccount = '8RM888',
		@AccumulateBalance = 0,
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT,
		@LeagueGroupID = '3,5,8,6,12,44,55'
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
			@LeastStake_Old    MONEY,	-- Add New Param #223442 
			@FollowAccountID_Old  INT,
			@UserName	NVARCHAR(50),
			@FollowAccount_Old	NVARCHAR(50),
			@AccumulateBalance_Old BIT,
			@LeagueGroupName VARCHAR(4000),
			@LeagueGroupID_Old VARCHAR(4000),
			@LeagueGroupName_Old VARCHAR(4000)  --Add param Log LeagueGroupID_Old

	SET @ErrCode = 0
	SET @StartRun = GETDATE()

	SELECT @UserName = username FROM Customer WITH(NOLOCK) WHERE custid = @CustID

	SELECT @LiveBetAccept_Old = LiveBetAccept, 
		   @SeizeBetTicket_Old = SeizeBetTicket, 
		   @MaxBet_Old = MaxBet, 
		   @MaxPerMatch_Old = MaxPerMatch, 
		   @FollowAccountID_Old = FollowAccount,
		   @LeagueGroupID_Old = LeagueGroupID,  -- Add Data Old LeagueGroupID
		   @AccumulateBalance_Old = AccumulateBalance,
		   @LeastStake_Old = LeastStake -- Add New Column #223442

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
	
	IF	ISNULL(@LiveBetAccept_Old,-99) = ISNULL(@LiveBetAccept,-99)
		AND ISNULL(@SeizeBetTicket_Old,200) = ISNULL(@SeizeBetTicket,200)
		AND ISNULL(@MaxBet_Old,-1) = ISNULL(@MaxBet,-1)
		AND ISNULL(@MaxPerMatch_Old,-1) = ISNULL(@MaxPerMatch,-1)
		AND ISNULL(@FollowAccountID_Old ,0)= ISNULL(@FollowAccountID,0)
		AND ISNULL(@AccumulateBalance_Old,0) = ISNULL(@AccumulateBalance,0)
		AND ISNULL(@LeagueGroupID_Old , '') = ISNULL(@LeagueGroupID, '')  -- Add validate #183663
		AND ISNULL(@LeastStake_Old, -1) = ISNULL(@LeastStake, -1)	-- Add New Param #223442

	BEGIN
		SELECT @ErrMsg = N'No change'
		RETURN
	END

	SELECT @FollowAccount_Old = username FROM Customer WITH(NOLOCK) WHERE custid = @FollowAccountID_Old
	
	BEGIN TRY
		UPDATE BetRestriction_Customer WITH(ROWLOCK)
		SET LiveBetAccept = @LiveBetAccept, 
			SeizeBetTicket = @SeizeBetTicket, 
			MaxBet = @MaxBet, 
			MaxPerMatch = @MaxPerMatch, 
			FollowAccount = @FollowAccountID,
			AccumulateBalance = @AccumulateBalance,
			LeagueGroupID = CASE WHEN @LeagueGroupID IS NULL THEN NULL Else @LeagueGroupID END, -- Edit LeagueGroupID #183663
			RepUpdateTime = dbo.f_GetDateTime2(),
			LeastStake = @LeastStake-- Add New Column #223442
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

	DECLARE @LogDataNew VARCHAR(4000), @LogDataOld VARCHAR(4000)


	SELECT @LeagueGroupName = CASE 
								WHEN @LeagueGroupID IS NULL THEN ' '
								WHEN @LeagueGroupID = 'All' THEN 'All'
								ELSE
									STUFF ((SELECT ', ' + lg.GroupName
									FROM DBACC.bodb02.dbo.LeagueGroup lg WITH (NOLOCK)
									INNER JOIN STRING_SPLIT (@LeagueGroupID , ',') AS t ON t.value = lg.GroupID
									FOR XML PATH('')), 1, 1, '')
							  END
		 , @LeagueGroupName_Old = CASE 
								WHEN @LeagueGroupID_Old IS NULL THEN ' '
								WHEN @LeagueGroupID_Old = 'All' THEN 'All'
								ELSE
									STUFF ((SELECT ', ' + lg.GroupName
									FROM DBACC.bodb02.dbo.LeagueGroup lg WITH (NOLOCK)
									INNER JOIN STRING_SPLIT (@LeagueGroupID_Old , ',') AS t ON t.value = lg.GroupID
									FOR XML PATH('')), 1, 1, '')
								END

	SELECT  @LogDataNew = '<R '
						+ 'UserName="'+ coalesce(cast(@UserName as varchar(50)),space(1)) + '" ' 
						+ 'LBA="'+ coalesce(cast(@LiveBetAccept as varchar(50)),'FUL') + '" '
						+ 'SBT="'+ CASE WHEN @SeizeBetTicket IS NULL THEN 'FUL' WHEN @SeizeBetTicket = 0 THEN 'None' ELSE cast(@SeizeBetTicket as varchar(50)) END  + '" '  
						+ 'LeagueGroupName="'+ coalesce(cast(@LeagueGroupName as varchar(4000)) , space(1)) + '" '  -- Add new LogChanged #183663
						+ 'FA="'+ coalesce(cast(@FollowAccount as varchar(50)),space(1)) + '" '
						+ 'AB="'+ CASE WHEN ISNULL(@AccumulateBalance,0) = 0 THEN 'No' ELSE 'Yes' END + '" '
						+ 'maxb="'+ coalesce(cast(@MaxBet as varchar(50)),space(1)) + '" ' 
						+ 'mpm="'+ coalesce(cast(@MaxPerMatch as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'LeastStake="'+ coalesce(cast(@LeastStake as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" ' 
						+ ' />',

			@LogDataOld = '<R '
						+ 'UserName="'+ coalesce(cast(@UserName as varchar(50)),space(1)) + '" ' 
						+ 'LBA="'+ coalesce(cast(@LiveBetAccept_Old as varchar(50)),'FUL') + '" '
						+ 'SBT="'+ CASE WHEN @SeizeBetTicket_Old IS NULL THEN 'FUL' WHEN @SeizeBetTicket_Old = 0 THEN 'None' ELSE cast(@SeizeBetTicket_Old as varchar(50)) END  + '" '  
						+ 'LeagueGroupName="'+ coalesce(cast(@LeagueGroupName_Old as varchar(4000)) , space(1)) + '" '  -- Add new LogChanged #183663
						+ 'FA="'+ coalesce(cast(@FollowAccount_Old as varchar(50)),space(1)) + '" '						
						+ 'AB="'+ CASE WHEN ISNULL(@AccumulateBalance_Old,0) = 0 THEN 'No' ELSE 'Yes' END + '" '
						+ 'maxb="'+ coalesce(cast(@MaxBet_Old as varchar(50)),space(1)) + '" ' 
						+ 'mpm="'+ coalesce(cast(@MaxPerMatch_Old as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'LeastStake="'+ coalesce(cast(@LeastStake_Old as varchar(50)),space(1)) + '" ' 
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