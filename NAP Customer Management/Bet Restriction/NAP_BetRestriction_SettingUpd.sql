/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_SettingUpd] (
	  @UserId				INT
	 ,@IP					VARCHAR(15) = ''
	 ,@SettingXML			XML
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
		- 20220615@Tacy: Hot modify Select Into statement to avoid dump [Redmine: #174035]

	Parameter explanation:
	@ErrCode : 
			 =  0 - succeed 
			 <> 0 - specific error

	Example: 
	DECLARE @SettingXML XML =
	N'<R>
		<Setting SettingId="1" LiveBetAccept="1" SeizeBetTicket="0" BetLimit="0"/> 
		<Setting SettingId="2" SeizeBetTicket="1" BetLimit="0"/> 
		<Setting SettingId="3" LiveBetAccept="1" SeizeBetTicket="0" /> 
	</R>'
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_SettingUpd
		@userid = 8,
		@SettingXML = @SettingXML,
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT
	SELECT @ErrCode, @ErrMsg

	*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SettingID	SMALLINT, @LiveBetAcceptStatus BIT, @SeizeBetTicketStatus BIT, @BetLimitStatus BIT
	, @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31710	
	, @SportType SMALLINT, @RestrictionLevel VARCHAR(50)	
	, @LiveBetAcceptStatus_Old BIT, @SeizeBetTicketStatus_Old BIT, @BetLimitStatus_Old BIT
	, @Type VARCHAR(20)

	CREATE TABLE #Setting (
			SettingId				SMALLINT,
			LiveBetAcceptStatus		BIT,
			SeizeBetTicketStatus	BIT,
			BetLimitStatus			BIT,
			IsProcessed				BIT,
			LogDataNew				VARCHAR(500),
			LogDataOld				VARCHAR(500),
			IsProcessedLog			BIT
			)

	SET @ErrCode = 0
	SET @StartRun = GETDATE()

	DECLARE @hDoc AS INT

	EXEC sp_xml_preparedocument @hDoc OUTPUT, @SettingXML

	INSERT INTO #Setting 
		(SettingId, LiveBetAcceptStatus, SeizeBetTicketStatus, BetLimitStatus, IsProcessed, LogDataNew, LogDataOld, IsProcessedLog)
	SELECT  st.SettingId,
			st.LiveBetAcceptStatus,
			st.SeizeBetTicketStatus,
			st.BetLimitStatus, 
			CAST (0 AS BIT) AS IsProcessed,
			CAST (NULL AS VARCHAR(500)) AS LogDataNew,
			CAST (NULL AS VARCHAR(500)) AS LogDataOld,
			CAST (0 AS BIT) AS IsProcessedLog
	FROM OPENXML(@hDoc, 'R/Setting')
	WITH 
	(
		 SettingId SMALLINT '@SettingId'
		,LiveBetAcceptStatus BIT '@LiveBetAccept'
		,SeizeBetTicketStatus BIT '@SeizeBetTicket'
		,BetLimitStatus BIT '@BetLimit'
	) st

	WHILE 1 = 1 
	BEGIN 
		SELECT TOP 1 
				@SettingID = SettingID,
				@LiveBetAcceptStatus = LiveBetAcceptStatus,
				@SeizeBetTicketStatus = SeizeBetTicketStatus,
				@BetLimitStatus = BetLimitStatus
		FROM  #Setting
		WHERE IsProcessed = 0

		IF @@ROWCOUNT = 0
			BREAK;

		SELECT	@LiveBetAcceptStatus_Old = LiveBetAcceptStatus,
				@SeizeBetTicketStatus_Old = SeizeBetTicketStatus,
				@BetLimitStatus_Old = BetLimitStatus,
				@SportType = SportType, 
				@RestrictionLevel = RestrictionLevel,
				@Type = CASE WHEN IsLicensee = 1 THEN 'Licensee' ELSE 'Credit' END
		FROM	BetRestriction_Setting bs WITH(NOLOCK) 
		WHERE   SettingID = @SettingID
		
		SELECT  @LiveBetAcceptStatus = ISNULL(@LiveBetAcceptStatus, @LiveBetAcceptStatus_Old),
				@SeizeBetTicketStatus = ISNULL(@SeizeBetTicketStatus, @SeizeBetTicketStatus_Old),
				@BetLimitStatus = ISNULL(@BetLimitStatus, @BetLimitStatus_Old)

		IF @LiveBetAcceptStatus = @LiveBetAcceptStatus_Old 
			AND @SeizeBetTicketStatus = @SeizeBetTicketStatus_Old 
			AND @BetLimitStatus = @BetLimitStatus_Old
		BEGIN
			DELETE FROM #Setting WHERE SettingID = @SettingID

			GOTO NextStep; -- No change
		END

		BEGIN TRY
			UPDATE	BetRestriction_Setting WITH(ROWLOCK)
			SET		LiveBetAcceptStatus = @LiveBetAcceptStatus,
					SeizeBetTicketStatus = @SeizeBetTicketStatus,
					BetLimitStatus = @BetLimitStatus
			WHERE   SettingID = @SettingID
		END TRY
		BEGIN CATCH
			SET @ErrCode = ERROR_NUMBER()
			SELECT @ErrMsg = ERROR_MESSAGE()
			RETURN
		END CATCH

		--> mark IsProcessed
		UPDATE #Setting 
		SET IsProcessed = 1 ,
			LogDataNew = '<R '
						+ 'RestrictionLevel="'+ coalesce(cast(@RestrictionLevel as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'Type="'+ coalesce(cast(@Type as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAcceptStatus="'+ coalesce(cast(@LiveBetAcceptStatus as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicketStatus="'+ coalesce(cast(@SeizeBetTicketStatus as varchar(50)),space(1)) + '" ' 
						+ 'BetLimitStatus="'+ coalesce(cast(@BetLimitStatus as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />',
			LogDataOld = '<R '
						+ 'RestrictionLevel="'+ coalesce(cast(@RestrictionLevel as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'Type="'+ coalesce(cast(@Type as varchar(50)),space(1)) + '" ' 
						+ 'LiveBetAcceptStatus="'+ coalesce(cast(@LiveBetAcceptStatus_Old as varchar(50)),space(1)) + '" ' 
						+ 'SeizeBetTicketStatus="'+ coalesce(cast(@SeizeBetTicketStatus_Old as varchar(50)),space(1)) + '" ' 
						+ 'BetLimitStatus="'+ coalesce(cast(@BetLimitStatus_Old as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" ' 
						+ ' />'
		WHERE SettingID = @SettingID

		NextStep:
	END

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @LogDataNew VARCHAR(500), @LogDataOld VARCHAR(500)

	--> Write log
	WHILE 1 = 1 
	BEGIN 
		SELECT TOP 1 
				@LogDataNew = LogDataNew,
				@LogDataOld = LogDataOld,
				@SettingID = SettingID
		FROM  #Setting
		WHERE IsProcessedLog = 0

		IF @@ROWCOUNT = 0
			BREAK;

		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@ActionId			= @ActionID,
			@TrackingValue		= @LogDataNew,
			@TrackingValue2		= @LogDataOld,
			@Duration			= @Duration 

		--> mark IsProcessedLog
		UPDATE #Setting 
		SET   IsProcessedLog = 1 
		WHERE SettingID = @SettingID
	END
	
	DROP TABLE #Setting
END
GO


