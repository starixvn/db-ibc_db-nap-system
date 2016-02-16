--NAP_ColossusBets_BonusTicket_Ins
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[NAP_ColossusBets_BonusTicket_InsUpd]
	@TransLogId		bigint
	, @CustID 		int
	, @UserID		int
	, @WinAmount 	money
	, @status		NVARCHAR(10)
	, @Choice		NVARCHAR(10)
	, @League		NVARCHAR(250)
	, @Match		NVARCHAR(250)
	, @Result		NVARCHAR(10)
	, @ErrCode 		int = 0 OUTPUT
	, @ErrMsg 		nvarchar(200) = '' OUTPUT  

AS
/*
Created: 20160215@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBTXN.bodb02
Original:[Dot_Member_ColossusBet_InsertDetails_VendorGame_Test]
Revisions:
	- 20160215@bobby.nguyen: #52058 - Update for CB change request - Insert bonus ticket
	
Param's Explanation:
	- @TransLogId 	: Ticket's refno [translog.translogid, bettrans.refno]
	- @CustID 		: Customer Id
	- @UserID		: Admin Id
	
*/
BEGIN
	SET NOCOUNT ON;
    
    DECLARE 
		@winlostdate 		SMALLDATETIME
		, @gameId			SMALLINT
		, @statusID			TINYINT
		, @Stake			money
		, @sdiscount 		decimal(9,8) 
		, @adiscount 		decimal(9,8) 
		, @discount 		decimal(9,8) 	
		, @comm 			money
		, @acomm 			money
		, @scomm 			money
		, @transdesc		NVARCHAR(1000)
		, @pool				VARCHAR(50)
		, @EventId 			INT
		, @TranId3rd		VARCHAR(64)
	
	SELECT @ErrCode 	= 0
		, @ErrMsg		= ''
		, @EventId 		= 0
		, @TranId3rd	= ''
    
	SELECT @TranId3rd 	= TranId3rd 
		, @winlostdate 	= winlostdate 
		, @eventId 		= eventID	
		, @pool			= custom2
		
	from dbo.translog with(nolock) 
	where custid		= @custID
		and TransLogId 	= @TransLogId 
		and statusID 	= 112
		AND gameId		= 18000
	
	IF (@TranId3rd IS NULL)
	BEGIN
		SELECT @ErrCode = 101
			, @ErrMsg	= 'Ticket is invalid.'
		RETURN
	END
	
    SELECT @gameId 		= 18006
		, @statusID		= CASE	WHEN @status = 'WON' THEN 112 
								WHEN @status = 'LOSE' THEN 113
								ELSE 0
							END
	
	SELECT @winAmount	= CASE WHEN @status = 'WON' THEN @winAmount ELSE 0 END
	SELECT @Stake		= CASE WHEN @status = 'WON' THEN @winAmount * 0.3 ELSE 0 END
	SELECT @sdiscount 	= CASE WHEN @status = 'WON' THEN 0.3 ELSE 0 END
		, @adiscount 	= CASE WHEN @status = 'WON' THEN 0.2 ELSE 0 END
		, @discount 	= CASE WHEN @status = 'WON' THEN 0.1 ELSE 0 END
	
	SELECT @scomm 		= @sdiscount * @winAmount
		, @acomm 		= @adiscount * @winAmount
		, @comm 		= @discount * @winAmount
	
	SELECT @transdesc 	= 'choice=' + @choice 
							+ ';league=' + @league 
							+ ';match=' + @match 
							+ ';result=' + @result 
	
	
	IF(NOT EXISTS (
			SELECT 1 FROM dbo.bettransm WITH(NOLOCK) 
			where custid	= @custID 
				and refno 	= @TransLogId 
				and bettype	= @gameId
		) 
	)
	BEGIN
		INSERT INTO dbo.bettransm 
		(transdate, hdp1, hdp2, odds, stake, [status], winlost, creator, refno,winlostdate,
		matchid,oddsspread, statusID, betcheck,oddsid,ruben,
		custid, discount, adiscount, sdiscount,comm,acomm,scomm,bettype,transdesc) 
		VALUES 
		(GETDATE(),0,0,0,0, @status,@winAmount,@UserID, @TransLogId,@winlostdate,
		204,0,@statusID,@TranId3rd,@EventId,0,
		@CustID,0,0,0,0,0,0,@GameID,@transdesc)		      
		       
		
	END
	ELSE
	BEGIN	
		UPDATE b
		SET status 		= @status
			,statusID 	= @statusID
			,winlost 	= @winAmount
			,transdesc	= @transdesc
		FROM dbo.bettransm b WITH(ROWLOCK, UPDLOCK)
		WHERE custid	= @custID 
			and refno 	= @TransLogId 
			and bettype	= @gameId
    END
	
	SELECT @ErrCode 	= @@ERROR
		, @ErrMsg		= ERROR_MESSAGE()
			
	IF(@status = 'WON' AND @ErrCode = 0)
	BEGIN
		INSERT INTO bettransm 
		(transdate, hdp1, hdp2, odds, stake, [status], winlost, creator, refno,winlostdate, 
		matchid,oddsspread, statusID, betcheck,oddsid,ruben,
		custid, discount, adiscount, sdiscount,comm,acomm,scomm,bettype) 
		VALUES 
		(GETDATE(),0,0,0,@Stake, 'LOSE',0,@CustID, @TransLogId,@winlostdate,
		204,0,113,@TranId3rd,@EventId,0,
		@CustID,isnull(@discount,0),isnull(@adiscount,0),isnull(@sdiscount,0),isnull(@comm,0),isnull(@acomm,0),isnull(@scomm,0),18003)
	END
	
	SELECT 
		@TransLogId 	AS refno
		, @CustID 		AS CustID
		, @WinAmount 	AS WinAmount
		, @status		AS Status
		, @statusID		AS StatusID
		, @EventId 		AS EventId
		, @TranId3rd	AS TranId3rd
		, @pool			AS Pool
		
	RETURN;
END
GO
GRANT EXECUTE ON [dbo].[NAP_ColossusBets_BonusTicket_InsUpd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_ColossusBets_BonusTicket_InsUpd] TO [vnteam]
GO
