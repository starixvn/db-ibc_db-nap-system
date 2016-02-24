--NAP_ColossusBets_BonusTicket_Ins
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[NAP_ColossusBets_BonusTicket_InsUpd]
	@RefNo			BIGINT
	, @CustID 		INT
	, @UserID		INT
	, @WinAmount 	MONEY
	, @status		NVARCHAR(10)
	, @Choice		NVARCHAR(50) 	= '-'
	, @League		NVARCHAR(250)	= '-'
	, @Match		NVARCHAR(250)	= '-'
	, @Result		NVARCHAR(50)	= '-'
	, @IP			VARCHAR(50)
	, @ErrCode 		INT = 0 OUTPUT
	, @ErrMsg 		NVARCHAR(200) = '' OUTPUT  

AS
/*
Created: 20160215@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBTXN.bodb02
Original:[Dot_Member_ColossusBet_InsertDetails_VendorGame_Test]
Revisions:
	- 20160215@bobby.nguyen: #52058 - Update for CB change request - Insert bonus ticket
	
Param's Explanation:
	- @RefNo 	: Ticket's refno [translog.translogid, bettrans.refno]
	- @CustID 		: Customer Id
	- @UserID		: Admin Id
	
*/
BEGIN
	SET NOCOUNT ON;
    
    DECLARE 
		@winlostdate 	SMALLDATETIME
		, @gameId		SMALLINT
		, @statusID		TINYINT
		, @Stake		MONEY
		, @sdiscount 	DECIMAL(9,8) 
		, @adiscount 	DECIMAL(9,8) 
		, @discount 	DECIMAL(9,8) 	
		, @comm 		MONEY
		, @acomm 		MONEY
		, @scomm 		MONEY
		, @transdesc	NVARCHAR(1000)
		, @pool			VARCHAR(50)
		, @EventId 		INT
		, @TranId3rd	VARCHAR(64)
		, @oldStatus 	NVARCHAR(10)
		, @hasUpdated 	BIT
	
	SELECT @ErrCode 	= 0
		, @ErrMsg		= ''
		, @EventId 		= 0
		, @TranId3rd	= ''
		, @hasUpdated	= 0
    
	-- select CB's ticket with won Jackpot
	SELECT @TranId3rd 	= TranId3rd 
		, @winlostdate 	= winlostdate 
		, @eventId 		= eventID	
		, @pool			= custom2
		
	FROM dbo.translog b WITH(NOLOCK) 
	WHERE custid		= @custID
		AND TransLogId 	= @RefNo 
		AND statusID 	= 112
		AND gameId		= 18000
		AND EXISTS ( -- Jackpot win
			SELECT 1 
			FROM dbo.bettransm WITH(NOLOCK) 
			WHERE custID 	= b.custID 
				AND refno 	= b.translogid 
				AND bettype = 18005
				AND statusID= 112
		)
		
	IF (@TranId3rd IS NULL
		OR @status NOT IN ('RUNNING', 'WON', 'LOSE')
	)
	BEGIN
		SELECT @ErrCode = 101
			, @ErrMsg	= 'Ticket or status is invalid.'
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
							+ ';ip=' + @IP
	
	-- check CB bonus ticket status
	SELECT @oldStatus 	= [status]
	FROM dbo.bettransm WITH(NOLOCK) 
	WHERE custid		= @custID 
		AND refno 		= @RefNo 
		AND bettype		= @gameId
				
	
	IF( @oldStatus IS NULL ) -- not exists
	BEGIN
		INSERT INTO dbo.bettransm 
		(transdate, hdp1, hdp2, odds, stake, [status], winlost, creator, refno,winlostdate,
		matchid,oddsspread, statusID, betcheck,oddsid,ruben,
		custid, discount, adiscount, sdiscount,comm,acomm,scomm,bettype,transdesc) 
		VALUES 
		(GETDATE(),0,0,0,0, @status,@winAmount,@UserID, @RefNo,@winlostdate,
		204,0,@statusID,@TranId3rd,@EventId,0,
		@CustID,0,0,0,0,0,0,@GameID,@transdesc)		      
		       
		SET @hasUpdated = 1
	END
	ELSE IF (@oldStatus = 'RUNNING') -- exists with running
	BEGIN	
		UPDATE b
		SET status 		= @status
			,statusID 	= @statusID
			,winlost 	= @winAmount
			,transdesc	= @transdesc
		FROM dbo.bettransm b WITH(ROWLOCK, UPDLOCK)
		WHERE custid	= @custID 
			AND refno 	= @RefNo 
			AND bettype	= @gameId
			
		SET @hasUpdated = 1
    END
	
	SELECT @ErrCode 	= @@ERROR
		, @ErrMsg		= ERROR_MESSAGE()
	
	-- check for inserting winning share
	IF(@hasUpdated 		= 1 
		AND (@oldStatus = 'RUNNING' OR @oldStatus IS NULL)
		AND @status 	= 'WON' 
		AND @ErrCode 	= 0
	)
	BEGIN
		INSERT INTO bettransm 
		(transdate, hdp1, hdp2, odds, stake, [status], winlost, creator, refno,winlostdate, 
		matchid,oddsspread, statusID, betcheck,oddsid,ruben,
		custid, discount, adiscount, sdiscount,comm,acomm,scomm,bettype) 
		VALUES 
		(GETDATE(),0,0,0,@Stake, 'LOSE',0,@CustID, @RefNo,@winlostdate,
		204,0,113,@TranId3rd,@EventId,0,
		@CustID,ISNULL(@discount,0),ISNULL(@adiscount,0),ISNULL(@sdiscount,0),ISNULL(@comm,0),ISNULL(@acomm,0),ISNULL(@scomm,0),18003)
	END
	
	SELECT 
		@RefNo 			AS refno
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
