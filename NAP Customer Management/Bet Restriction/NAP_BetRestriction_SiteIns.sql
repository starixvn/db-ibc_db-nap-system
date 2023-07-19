/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_SiteIns] (
	  @SiteID				INT
	 ,@UserId				INT
	 ,@IP					VARCHAR(15) = ''
	 ,@SportType			SMALLINT = 1
	 ,@LiveBetAccept		SMALLINT = NULL
	 ,@SeizeBetTicket		TINYINT = NULL
	 ,@FollowAccount		NVARCHAR(50) = NULL
	 ,@AccumulateBalance	BIT = 0
	 ,@ErrMsg				NVARCHAR(MAX) = '' OUTPUT	
	 ,@ErrCode				TINYINT = 0 OUTPUT
)
AS
/*
	Created: 20190815@Eden
	Task : Insert Bet Restriction for Site
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]
	- 20230613@Luke: Option to apply Seize Bet if reach risk balance [Redmine: #187771]

	Parameter explanation:
	@ErrCode = :
			0 - succeed , can be inserted/Update
			1 - Invalid Site.
			2 - This Site has already exists in the Bet Restriction list.
			3 - Invalid 8RM Account.

	Example: 
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_SiteIns
		@SiteID = 2, 
		@UserId =8,
		@LiveBetAccept = NULL , 
		@SeizeBetTicket = 0 , 
		@FollowAccount = NULL,--'8RM888',
		@AccumulateBalance = 0,
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT
	SELECT @ErrCode, @ErrMsg
	
	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31704
	DECLARE @site NVARCHAR(50)
	DECLARE @FollowAccountID INT

	SET @ErrCode = 0
	SET @StartRun = GETDATE()

	IF NOT EXISTS(	SELECT TOP 1 1 
				FROM  Site WITH(NOLOCK)
				WHERE SiteID = @SiteID )
	BEGIN
		SET @ErrCode = 1
		SELECT @ErrMsg = 'Invalid Site.' 
		RETURN
	END

	IF EXISTS(	SELECT TOP 1 1 
				FROM BetRestriction_Site WITH(NOLOCK)
				WHERE SiteID = @SiteID AND SportType = @SportType )
	BEGIN
		SET @ErrCode = 2
		SELECT @ErrMsg = 'This site has already existed in the Bet Restriction list.' 
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

	SELECT @Site = Site FROM Site WITH(NOLOCK) WHERE siteid = @SiteID
	
	BEGIN TRY
		INSERT INTO BetRestriction_Site(
		SiteID, 
		SportType,
        LiveBetAccept, 
        SeizeBetTicket, 
        FollowAccount,
		AccumulateBalance
       )
    SELECT  @SiteID, 
            @SportType,
			@LiveBetAccept, 
            @SeizeBetTicket, 
            @FollowAccountID,
			@AccumulateBalance
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SELECT @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @LogDataNew VARCHAR(500)
	SELECT  @LogDataNew = '<R '
						+ 'Site="'+ coalesce(cast(@Site as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'LBA="'+ coalesce(cast(@LiveBetAccept as varchar(50)),'FUL') + '" '
						+ 'SBT="'+ CASE WHEN @SeizeBetTicket IS NULL THEN 'FUL' WHEN @SeizeBetTicket = 0 THEN 'None' ELSE cast(@SeizeBetTicket as varchar(50)) END  + '" '  
						+ 'FA="'+ coalesce(cast(@FollowAccount as varchar(50)),space(1)) + '" '
						+ 'AB="'+ CASE WHEN ISNULL(@AccumulateBalance,0) = 0 THEN 'No' ELSE 'Yes' END + '" '
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />'

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserId				= @UserId,
		--@CustId				= @CustId,
		@ActionId			= @ActionID,
		@TrackingValue		= @LogDataNew,
		@Duration			= @Duration
END
GO


