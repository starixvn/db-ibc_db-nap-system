/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[NAP_PayoutTrans_Jackpot_SelBetTicket]    Script Date: 1/9/2018 1:21:36 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[NAP_PayoutTrans_Jackpot_SelBetTicket]
	@RefNo			BIGINT,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS
/*
	Created: 20180109@Paul
	Task : #88709 - OneRNG Jackpot Payout Management
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20180109@Paul: Initial version
		- 20180502@Paul: Hot fix [RedmineID: #94448]
	
	Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @WinlostDate SMALLDATETIME;

	SELECT @WinlostDate = WinlostDate
	FROM dbo.PayoutTrans WITH(NOLOCK)
	WHERE RefNo = @RefNo;

	IF @WinlostDate > @MoveBetsDay
	BEGIN
		SELECT RefNo2
		FROM dbo.bettransRnG WITH(NOLOCK)
		WHERE transid = @RefNo;
	END

	IF @WinlostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
	BEGIN
		SELECT RefNo2
		FROM dbo.bettransRnG14 WITH(NOLOCK)
		WHERE transid = @RefNo;
	END

	IF @WinlostDate < @BalanceUpDay
	BEGIN
		SELECT RefNo2
		FROM bodb_Archive.dbo.bettransRnG_bk WITH(NOLOCK)
		WHERE transid = @RefNo
			AND winlostdate = @WinlostDate;
	END

	SET NOCOUNT OFF;
END

GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_Jackpot_SelBetTicket] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_Jackpot_SelBetTicket] TO [vnteam] 
GO

