USE bodb02
GO
ALTER PROCEDURE [NAP_PayoutTrans_ColossusBet_Complete]
	@Transid 	BIGINT,
	@CustID 	INT, 
	@ErrCode 	INT = -1 OUTPUT,
	@ErrMsg 	NVARCHAR(200) = '' OUTPUT    
AS
/*
Created: 20151012@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBTXN.bodb02
Original:
Revisions:
	- 20151228@Austin: CREATE ,for ColossusBet CSDPayOut
	- 20160106@bobby.nguyen: #50364 - Update for CB change request
	
Param's Explanation:
	
*/
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE @translogid 	BIGINT 
		,@winlostdate 		SMALLDATETIME
	
	SET @ErrCode =-1
	
	SELECT TOP 1
		@translogid 	= refno        
		,@ErrCode 		= 0
		,@ErrMsg 		= 'success'
		,@winlostdate 	= CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)			  
	FROM dbo.bettrans WITH (NOLOCK)
	WHERE transid 		= @Transid 
		AND custid 		= @custid 
		AND statusID 	= 0

	IF (ISNULL(@ErrCode,-1) = -1)
	BEGIN
			SELECT  @ErrCode = 101,
			@ErrMsg = 'No ticket log.'
			RETURN
	END        
		

	UPDATE dbo.bettransm WITH (ROWLOCK, UPDLOCK)
		SET winlostdate = @winlostdate
		WHERE refno = @translogid 
		AND custid	= @custID

	UPDATE dbo.translog with (ROWLOCK, UPDLOCK)
		SET winlostdate 	= @winlostdate		
		WHERE translogid 	= @translogid 
			AND custid 		= @custid
	
	UPDATE dbo.bettrans with (ROWLOCK, UPDLOCK)
		SET winlostdate = @winlostdate
			,[status]	= N'WON' 
			, statusID	= 112
			, betcheck	= ''
			, ruben		= 1
		WHERE transid	= @Transid 
			AND custid 	= @custid
			
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_ColossusBet_Complete] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_ColossusBet_Complete] TO [vnteam]
GO
