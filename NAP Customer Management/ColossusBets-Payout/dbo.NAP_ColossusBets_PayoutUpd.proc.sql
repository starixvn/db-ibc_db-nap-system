USE bodb02
GO
ALTER PROCEDURE [dbo].[NAP_ColossusBets_PayoutUpd]
(
	@BetId			BIGINT
	, @CreatedBy	INT
	, @StatusId		TINYINT
	, @PayStatus	NVARCHAR(20)
	, @PayNote		NVARCHAR(1000) 	= ''
	, @IP 			VARCHAR(50)
	, @ErrCode 		INT 			= 0 OUTPUT
	, @ErrMsg 		NVARCHAR(200) 	= '' OUTPUT
)
AS
/*
Created: 20151012@bobby.nguyen
Task : #44588 - Colossus Bets Payout Management
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
		, @PayStatus		= ISNULL(@PayStatus, '')
		, @PayNote			= ISNULL(@PayNote, '')
		, @IP				= ISNULL(@IP, '')
		, @UpdDate			= GETDATE()
	
	IF (@BetId 				> 0
		AND @CreatedBy		> 0
		AND @StatusId 		>= 0
		AND @PayStatus 		<> ''
		AND @IP				<> ''
	)
	BEGIN
		UPDATE p
		SET [StatusId] 		= @StatusId
		  ,[PayStatus] 		= @PayStatus
		  ,[LastModifyDate] = @UpdDate
		  ,[LastModifyBy] 	= @CreatedBy
		  
		FROM [dbo].[PayoutTrans] p WITH(ROWLOCK, UPDLOCK)
		WHERE p.[PayoutTransId] = @BetId
		
		IF(@@ERROR = 0)
		BEGIN
			INSERT INTO [dbo].[PayoutDetail]
			   ([PayoutTransId]
			   ,[CreatedDate]
			   ,[CreatedBy]
			   ,[StatusId]
			   ,[PayStatus]
			   ,[PayNote]
			   ,[IP])
			VALUES
			   (@BetId
			   ,@UpdDate
			   ,@CreatedBy
			   ,@StatusId
			   ,@PayStatus
			   ,@PayNote
			   ,@IP)
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
GRANT EXECUTE ON [dbo].[NAP_ColossusBets_PayoutUpd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_ColossusBets_PayoutUpd] TO [vnteam]
GO