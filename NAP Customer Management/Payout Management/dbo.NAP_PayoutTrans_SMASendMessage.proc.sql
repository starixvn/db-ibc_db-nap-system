USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_PayoutTrans_SelDetail]    Script Date: 11/12/2015 11:40:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[NAP_PayoutTrans_SMASendMessage]
(
	@Creator 		INT
	, @custId 		INT
	, @BettransId 	BIGINT
)
AS
/*
Created: 20151012@bobby.nguyen
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBACC.bodb02
Original:
Revisions:
	- 20160106@bobby.nguyen: #50364 - Update for CB change request
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @CreatorName			NVARCHAR(50)
			, @recommend			INT
			, @mrecommend			INT
			, @srecommend			INT
			, @recommendUserName 	NVARCHAR(50)
			, @mrecommendUserName	NVARCHAR(50)
			, @srecommendUserName	NVARCHAR(50)
			, @MessageId			INT
			, @PostTime				DATETIME
			, @SMAMessage			NVARCHAR(MAX)
			
	SELECT @CreatorName	= username 
		, @SMAMessage	= N'Dear value customer, a member under your line had won a Colossus Bet prize. You will receive 10% of the prize as winning share.'
		, @PostTime		= GETDATE()
	FROM CustDB.dbo.customer WITH(NOLOCK)
	WHERE custId = @Creator
			
	EXECUTE [DBMSG].[bodb_Message].[dbo].[Dot_Msg_SetMessage2] 
	   @MessageId 	= @MessageId OUTPUT
	  ,@Content_en 	= @SMAMessage
	  ,@Content_ch 	= NULL
	  ,@Content_cs 	= NULL
	  ,@Content_jp 	= NULL
	  ,@Content_it 	= NULL
	  ,@Content_th 	= NULL
	  ,@Content_ko 	= NULL
	  ,@Content_es 	= NULL
	  ,@Content_vn 	= NULL
	  ,@Content_id 	= NULL
	  ,@MsgType		= 1
	  ,@IsSticky	= 1
	  ,@Creator 	= @Creator
	  ,@CreatorName	= @CreatorName
	  ,@IsTest		= 0
	  ,@MatchId		= 204
	  ,@IsBatch		= 0
	  
	IF(@MessageId > 0)
	BEGIN
		
		SELECT @recommend	= recommend
			, @mrecommend	= mrecommend
			, @srecommend	= srecommend
			
		FROM CustDB.dbo.custinfo WITH(NOLOCK)
		WHERE custId = @custId
		
		SELECT @recommendUserName 	= CASE WHEN roleid = 2 THEN username ELSE @recommendUserName END
			,@mrecommendUserName 	= CASE WHEN roleid = 3 THEN username ELSE @mrecommendUserName END
			,@srecommendUserName 	= CASE WHEN roleid = 4 THEN username ELSE @srecommendUserName END
		FROM CustDB.dbo.custinfo WITH(NOLOCK)
		WHERE custId IN (@recommend, @mrecommend, @srecommend)
		
		-- send agent message
		EXECUTE [DBMSG].[bodb_Message].[dbo].[Dot_Msg_SetUsrMessage] 
			@MessageId 		= @MessageId
			,@TargetId		= @recommend
			,@TargetName	= @recommendUserName
			,@isRead		= 0
			,@BetTransId 	= @BettransId
			,@PostTime		= @PostTime	
			,@Creator		= @Creator
		
		-- send master message
		EXECUTE [DBMSG].[bodb_Message].[dbo].[Dot_Msg_SetUsrMessage] 
			@MessageId 		= @MessageId
			,@TargetId		= @mrecommend
			,@TargetName	= @mrecommendUserName
			,@isRead		= 0
			,@BetTransId 	= @BettransId
			,@PostTime		= @PostTime	
			,@Creator		= @Creator
			
		-- send super message
		EXECUTE [DBMSG].[bodb_Message].[dbo].[Dot_Msg_SetUsrMessage] 
			@MessageId 		= @MessageId
			,@TargetId		= @srecommend
			,@TargetName	= @srecommendUserName
			,@isRead		= 0
			,@BetTransId 	= @BettransId
			,@PostTime		= @PostTime	
			,@Creator		= @Creator
		
	END

END
GO
