/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CustomerDel] 
	  @CustID		INT
	 ,@UserId		INT
	 ,@SportType    SMALLINT = 1
	 ,@ErrMsg		NVARCHAR(MAX) = '' OUTPUT
	 ,@ErrCode		TINYINT = 0 OUTPUT
AS
/*
	Created: 20190815@Eden
	Task : Delete Bet Restriction Customer 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP [RedmineID: #117727]

	Parameter explanation:
	@ErrCode = :
			0 - succeed 

	Example: 
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_CustomerDel 
	    @CustID = 1176092,	
		@UserID = 8,
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT
	SELECT @ErrCode, @ErrMsg
	
	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31703
	DECLARE @site VARCHAR(10)
	DECLARE @LiveBetAccept_Old  SMALLINT, 
			@SeizeBetTicket_Old TINYINT, 
			@MaxBet_Old         MONEY, 
			@MaxPerMatch_Old    MONEY, 
			@FollowAccount_Old  INT;

	SET @ErrCode = 0

	SET @StartRun = GETDATE()

	SELECT @site = Site FROM Customer c WITH(NOLOCK) WHERE c.custid = @CustID
	
	SELECT @LiveBetAccept_Old = LiveBetAccept, 
		   @SeizeBetTicket_Old = SeizeBetTicket, 
		   @MaxBet_Old = MaxBet, 
		   @MaxPerMatch_Old = MaxPerMatch, 
		   @FollowAccount_Old = FollowAccount
	FROM BetRestriction_Customer WITH(NOLOCK)
	WHERE CustID = @CustID
		  AND SportType = @SportType;
	
	BEGIN TRY
		DELETE
		FROM BetRestriction_Customer WITH(UPDLOCK,ROWLOCK)
		WHERE CustID = @CustID AND SportType = @SportType
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SELECT @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @LogData VARCHAR(500)
	SELECT  @LogData = '<R'
						+ 'CustID="'+ coalesce(cast(@CustID as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAccept="'+ coalesce(cast(@LiveBetAccept_Old as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicket="'+ coalesce(cast(@SeizeBetTicket_Old as varchar(50)),space(1)) + '" ' 
						+ 'MaxBet="'+ coalesce(cast(@MaxBet_Old as varchar(50)),space(1)) + '" ' 
						+ 'MaxPerMatch="'+ coalesce(cast(@MaxPerMatch_Old as varchar(50)),space(1)) + '" ' 
						+ 'FollowAccount="'+ coalesce(cast(@FollowAccount_Old as varchar(50)),space(1)) + '" ' 
						+ ' />'
		

	IF @site = 'CN88'
	BEGIN
		EXEC dbo.CS_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionID,
			@TrackingValue		= @LogData,
			@Duration			= @Duration
	END
	ELSE -- MBC
	BEGIN
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionID,
			@TrackingValue		= @LogData,
			@Duration			= @Duration
	END	  
END
GO


