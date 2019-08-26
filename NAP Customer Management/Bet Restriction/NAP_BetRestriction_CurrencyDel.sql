/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CurrencyDel] 
	   @ExchangeID	INT = NULL
	  ,@UserId		INT
	  ,@IP			VARCHAR(15) = ''
	  ,@SportType	SMALLINT = 1
	  ,@Type		TINYINT = NULL
	  ,@ErrMsg		NVARCHAR(MAX) = '' OUTPUT	
	  ,@ErrCode		TINYINT = 0 OUTPUT
AS
/*
	Created: 20190815@Eden
	Task : Delete Bet Restriction Currency 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP [RedmineID: #117727]

	Parameter explanation:
	@ErrCode =: 
			0 - succeed 
			4- This record no longer exists in the Bet Restriction List.

	Example:
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT 
	EXEC NAP_BetRestriction_CurrencyDel 
		@ExchangeID = 35 ,
		@UserId = 8,
		@Type = 1,
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT
	SELECT @ErrCode, @ErrMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31709
	DECLARE @LiveBetAccept_Old  SMALLINT, 
			@SeizeBetTicket_Old TINYINT, 
			@FollowAccountID_Old  INT,
			@FollowAccount_Old	NVARCHAR(50),
			@Currency	NVARCHAR(50),
			@vType VARCHAR(10)

	SET @ErrCode = 0
	SET @StartRun = GETDATE()

	SELECT @LiveBetAccept_Old = LiveBetAccept, 
		   @SeizeBetTicket_Old = SeizeBetTicket, 
		   @FollowAccountID_Old = FollowAccount
	FROM BetRestriction_Currency WITH(NOLOCK)
	WHERE ExchangeID = @ExchangeID	
		  ANd Type = @Type
		  AND SportType = @SportType;
	
	SELECT @FollowAccount_Old = username FROM Customer WITH(NOLOCK) WHERE custid = @FollowAccountID_Old
	SELECT @Currency = Currency FROM exchange WITH(NOLOCK) WHERE exchangeid = @ExchangeID
	SELECT @vType = CASE WHEN @Type = 0 THEN 'All' 
						 WHEN @Type = 1 THEN 'Credit'
						 WHEN @Type = 2 THEN 'Licensee' END

	BEGIN TRY
		DELETE
		FROM  BetRestriction_Currency WITH(UPDLOCK,ROWLOCK)
		WHERE ExchangeID = @ExchangeID AND [Type] = @Type AND SportType = @SportType 

		IF @@ROWCOUNT = 0
		BEGIN
			SET @ErrCode = 4
			SELECT @ErrMsg = 'This record no longer exists in the Bet Restriction List.'
			RETURN
		END
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
						+ 'Currency="'+ coalesce(cast(@Currency as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'Type="'+ coalesce(cast(@vType as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAccept="'+ coalesce(cast(@LiveBetAccept_Old as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicket="'+ coalesce(cast(@SeizeBetTicket_Old as varchar(50)),space(1)) + '" ' 
						+ 'FollowAccount="'+ coalesce(cast(@FollowAccount_Old as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />'
		

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserId				= @UserId,
		--@CustId				= @CustId,
		@ActionId			= @ActionID,
		@TrackingValue		= @LogData,
		@Duration			= @Duration  
	
END
GO


