/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_SiteUpd] (
	  @SiteID			INT
	 ,@UserId			INT
	 ,@SportType		SMALLINT = 1
	 ,@LiveBetAccept	SMALLINT
	 ,@SeizeBetTicket	TINYINT = NULL
	 ,@FollowAccount	NVARCHAR(50) = NULL
	 ,@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
	 ,@ErrCode			TINYINT = 0 OUTPUT
)
AS
/*
	Created: 20190815@Eden
	Task : Update Bet Restriction for Site
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]

	Parameter explanation:
	@ErrCode = :
			0 - succeed 
			3 - Invalid 8RM Account.

	Example: 
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_SiteUpd
		@SiteID = 329, 
		@UserId = 8,
		@LiveBetAccept = 10 , 
		@SeizeBetTicket = 20 , 
		@FollowAccount = '8RM888',
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT
	SELECT @ErrCode, @ErrMsg
	
	*/
BEGIN	
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31705
	DECLARE @FollowAccountID INT
	DECLARE @LiveBetAccept_Old  SMALLINT, 
			@SeizeBetTicket_Old TINYINT, 
			@FollowAccount_Old  INT;
	
	SET @ErrCode = 0
	SET @StartRun = GETDATE()

	EXEC NAP_BetRestriction_ValidateFollowAccount
		@FollowAccount = @FollowAccount,
		@FollowAccountID  = @FollowAccountID OUTPUT

	IF @FollowAccount IS NOT NULL AND @FollowAccountID IS NULL
	BEGIN
		SET @ErrCode = 3
		SELECT @ErrMsg = CASE WHEN @ErrCode = 3 THEN 'Invalid 8RM Account.'  END
		RETURN
	END

	SELECT @LiveBetAccept_Old = LiveBetAccept, 
		   @SeizeBetTicket_Old = SeizeBetTicket,  
		   @FollowAccount_Old = FollowAccount
	FROM BetRestriction_Site WITH(NOLOCK)
	WHERE SiteID = @SiteID
		  AND SportType = @SportType;
	
	IF	@LiveBetAccept_Old = @LiveBetAccept 
		AND ISNULL(@SeizeBetTicket_Old,0) = ISNULL(@SeizeBetTicket,0)
		AND ISNULL(@FollowAccount_Old ,0)= ISNULL(@FollowAccountID,0)
	BEGIN
		SELECT @ErrMsg = N'No change'
		RETURN
	END

	BEGIN TRY
		UPDATE BetRestriction_Site WITH(ROWLOCK)
		SET LiveBetAccept = @LiveBetAccept, 
			SeizeBetTicket = @SeizeBetTicket, 
			FollowAccount = @FollowAccountID
		WHERE SiteID = @SiteID AND SportType = @SportType
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SELECT @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)
	SELECT  @LogDataNew = '<R'
						+ 'SiteID="'+ coalesce(cast(@SiteID as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAccept="'+ coalesce(cast(@LiveBetAccept as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicket="'+ coalesce(cast(@SeizeBetTicket as varchar(50)),space(1)) + '" ' 
						+ 'FollowAccount="'+ coalesce(cast(@FollowAccountID as varchar(50)),space(1)) + '" ' 
						+ ' />',
			@LogDataOld = '<R'
						+ 'SiteID="'+ coalesce(cast(@SiteID as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAccept="'+ coalesce(cast(@LiveBetAccept_Old as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicket="'+ coalesce(cast(@SeizeBetTicket_Old as varchar(50)),space(1)) + '" ' 
						+ 'FollowAccount="'+ coalesce(cast(@FollowAccount_Old as varchar(50)),space(1)) + '" ' 
						+ ' />'
		
	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserId				= @UserId,
		--@CustId				= @CustId,
		@ActionId			= @ActionID,
		@TrackingValue		= @LogDataNew,
		@TrackingValue2		= @LogDataOld,
		@Duration			= @Duration                     
END
GO


