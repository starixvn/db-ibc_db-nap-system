/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_SettingUpd] (
	  @UserId				INT
	 ,@IP					VARCHAR(15) = ''
	 ,@SportType			SMALLINT
	 ,@RestrictionLevel		VARCHAR(50)
	 ,@IsLicensee			BIT
	 ,@LiveBetAcceptStatus	BIT 
	 ,@SeizeBetTicketStatus BIT
	 ,@BetLimitStatus		BIT
	 ,@ErrMsg				NVARCHAR(MAX) = '' OUTPUT	
	 ,@ErrCode				TINYINT = 0 OUTPUT
)
AS
/*
	Created: 20190829@Eden
	Task : Update Bet Restriction setting 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190829@Eden: Create New SP [RedmineID: #117727]

	Parameter explanation:
	@ErrCode : 
			 =  0 - succeed 
			 <> 0 - specific error

	Example: 
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_SettingUpd
		@SportType = 1, 
		@RestrictionLevel = 'BetRestriction_Customer',
		@IsLicensee = 0,
		@userid = 10,
		@LiveBetAcceptStatus = 1,	
		@SeizeBetTicketStatus = 1, 
		@BetLimitStatus = 1,	
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT
	SELECT @ErrCode, @ErrMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT 		
			, @LiveBetAcceptStatus_Old BIT, @SeizeBetTicketStatus_Old BIT, @BetLimitStatus_Old BIT
			, @Type VARCHAR(20)

	SET @ErrCode = 0
	SET @StartRun = GETDATE()

	SELECT	@LiveBetAcceptStatus_Old = LiveBetAcceptStatus,
			@SeizeBetTicketStatus_Old = SeizeBetTicketStatus,
			@BetLimitStatus_Old = BetLimitStatus,
			@Type = CASE WHEN @IsLicensee = 1 THEN 'Licensee' ELSE 'Credit' END
	FROM	BetRestriction_Setting bs WITH(NOLOCK) 
	WHERE   SportType = @SportType 
			AND RestrictionLevel = @RestrictionLevel
			AND IsLicensee = @IsLicensee
	
	IF @LiveBetAcceptStatus = @LiveBetAcceptStatus_Old 
		AND @SeizeBetTicketStatus = @SeizeBetTicketStatus_Old 
		AND @BetLimitStatus = @BetLimitStatus_Old
	BEGIN
		SELECT @ErrMsg = N'No change'
		RETURN
	END

	BEGIN TRY
		UPDATE	BetRestriction_Setting WITH(ROWLOCK)
		SET		LiveBetAcceptStatus = @LiveBetAcceptStatus,
				SeizeBetTicketStatus = @SeizeBetTicketStatus,
				BetLimitStatus = @BetLimitStatus
		WHERE   SportType = @SportType 
				AND RestrictionLevel = @RestrictionLevel
				AND IsLicensee = @IsLicensee
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
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'RestrictionLevel="'+ coalesce(cast(@RestrictionLevel as varchar(50)),space(1)) + '" ' 
						+ 'Type="'+ coalesce(cast(@Type as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAcceptStatus="'+ coalesce(cast(@LiveBetAcceptStatus as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicketStatus="'+ coalesce(cast(@SeizeBetTicketStatus as varchar(50)),space(1)) + '" ' 
						+ 'BetLimitStatus="'+ coalesce(cast(@BetLimitStatus as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />',
			@LogDataOld = '<R '
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'RestrictionLevel="'+ coalesce(cast(@RestrictionLevel as varchar(50)),space(1)) + '" ' 
						+ 'Type="'+ coalesce(cast(@Type as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAcceptStatus="'+ coalesce(cast(@LiveBetAcceptStatus_Old as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicketStatus="'+ coalesce(cast(@SeizeBetTicketStatus_Old as varchar(50)),space(1)) + '" ' 
						+ 'BetLimitStatus="'+ coalesce(cast(@BetLimitStatus_Old as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" ' 
						+ ' />'

	--EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
	--	@UserId				= @UserId,
	--	--@CustId				= @CustId,
	--	@ActionId			= @ActionID,
	--	@TrackingValue		= @LogDataNew,
	--	@Duration			= @Duration 
END
GO


