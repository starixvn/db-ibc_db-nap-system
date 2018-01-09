/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[NAP_PayoutTrans_Jackpot_SelBetTicket]    Script Date: 1/9/2018 1:21:36 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[NAP_PayoutTrans_Jackpot_SelBetTicket]
	@RefNo BIGINT
AS
/*
	Created: 20180109@Paul
	Task : #88709 - OneRNG Jackpot Payout Management
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20180109@Paul: Initial version
	
	Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;

	SELECT RefNo2
	FROM dbo.bettransRnG WITH(NOLOCK)
	WHERE transid = @RefNo;

	SET NOCOUNT OFF;
END

GO
GRANT EXECUTE ON [dbo].[NAP_PayoutTrans_Jackpot_SelBetTicket] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_PayoutTrans_Jackpot_SelBetTicket] TO [vnteam] 
GO

