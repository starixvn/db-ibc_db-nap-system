USE bodb02
GO
ALTER PROCEDURE [dbo].[NAP_PayoutTrans_Upd]
(
	@PayoutTransId		INT
	, @Creator			INT
	, @PayoutStatusId	TINYINT
	, @PayoutStatus		NVARCHAR(20)
	, @PayoutNote		NVARCHAR(1000) 	= ''
	, @IP 				VARCHAR(50)
	, @ErrCode 			INT 			= 0 OUTPUT
	, @ErrMsg 			NVARCHAR(200) 	= '' OUTPUT
)
AS
/*
Created: 20151012@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBTXN.bodb02
Original:
Revisions:
	- 20151012@bobby.nguyen: Initial
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @UpdDate 		SMALLDATETIME
	
	SELECT @ErrCode 		= 0
		, @ErrMsg 			= ''
		, @PayoutStatus		= ISNULL(@PayoutStatus, '')
		, @PayoutNote		= ISNULL(@PayoutNote, '')
		, @IP				= ISNULL(@IP, '')
		, @UpdDate			= GETDATE()
	
	IF (@PayoutTransId			> 0
		AND @Creator			> 0
		AND @PayoutStatusId 	> 0
		AND @PayoutStatus 		<> ''
		AND @IP					<> ''
	)
	BEGIN
		UPDATE p
		SET [PayoutStatusId] 	= @PayoutStatusId
		  ,[PayoutStatus] 		= @PayoutStatus
		  
		FROM [dbo].[PayoutTrans] p WITH(ROWLOCK, UPDLOCK)
		WHERE p.[PayoutTransId] = @PayoutTransId
		
		IF(@@ERROR = 0)
		BEGIN
			BEGIN TRY
				
				INSERT INTO [DBLOG].[bodb_CustomerLog].[dbo].[PayoutDetail]
				   ([PayoutTransId]
				   ,[CreatedDate]
				   ,[Creator]
				   ,[PayoutStatusId]
				   ,[PayoutStatus]
				   ,[PayoutNote]
				   ,[IP])
				VALUES
				   (@PayoutTransId
				   ,@UpdDate
				   ,@Creator
				   ,@PayoutStatusId
				   ,@PayoutStatus
				   ,@PayoutNote
				   ,@IP)
			END TRY
			BEGIN CATCH
				INSERT INTO [bodb_CustomerLog].[dbo].[PayoutDetail]
				   ([PayoutTransId]
				   ,[CreatedDate]
				   ,[Creator]
				   ,[PayoutStatusId]
				   ,[PayoutStatus]
				   ,[PayoutNote]
				   ,[IP])
				VALUES
				   (@PayoutTransId
				   ,@UpdDate
				   ,@Creator
				   ,@PayoutStatusId
				   ,@PayoutStatus
				   ,@PayoutNote
				   ,@IP)
			END CATCH
	
			
		END
		SELECT @ErrCode 	= ISNULL(ERROR_NUMBER(), 0)
			, @ErrMsg		= ISNULL(ERROR_MESSAGE(), 0)
	END
	ELSE
	BEGIN
	
		SELECT @ErrCode 	= 1001
			, @ErrMsg		= 'Updated info is invalid.'
		
	END
	
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_Upd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_Upd] TO [vnteam]
GO