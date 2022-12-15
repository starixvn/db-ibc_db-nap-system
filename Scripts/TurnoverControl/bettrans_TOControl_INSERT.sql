/*<info serverAlias="DB053-bodb02" executers="" isFunction="0"></info>*/
ALTER TRIGGER [dbo].[bettrans_TOControl_INSERT]
   ON  [dbo].[bettrans]
   AFTER INSERT
AS 
/*
	Created: Helen
	Date: 2017-09-20
	Task: Insert new CustId to Gobal setting (multiple insert)
	DB: DB053.bodb02
	
	- Revisions:
		- 20170920@Helen: TO Control Phase 3 - [Redmine: 75557]
		- 20171110@Helen: Enhance performance for TO trigger - [Redmine: 86052]
		- 20171212@Helen: Support UUS - Implement some change request from OPS Team - [Redmine: 85638]
		- 20180315@Helen: Integrate Super Live product - [Redmine:89986]
		- 20180622@Don: Tuning trigger - [Redmine:97313]
		- 20180626@Helen: Tuning trigger - [Redmine:97442]
		- 20181219@Kan: TO Control - Change condition of bettype - [Redmine: 106656]
		- 20190305@Razor: SMA TO Control - Integrate Bet Builder - [Redmine: 108391]
		- 20220711@July: Using sportbettypematrix to detect bettype of sportbook - [Redmine: 175141]
		- 20220520@Kathy: Alpha - My Monitor Accounts for Risk & Control [Redmine:170467]
		- 20221121@Kathy: Check setting when capture data [Redmine:#180716]
		- 20221215@Kathy: Monitor SMA win loss [Redmine:#179067]

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @srecommend INT, @bettype SMALLINT, @statusID TINYINT, @TransID BIGINT, @Recommend INT, @mRecommend INT, @CustId INT
	DECLARE @isvalidSB BIT = 0
			,@isvalidSB_3rdSB BIT = 0

	SELECT @srecommend = srecommend, @bettype = bettype, @statusID = statusID, @TransID = transid, @Recommend = recommend, @mRecommend = mrecommend, @CustId = custid
	FROM inserted 
	
	SELECT	@isvalidSB = MAX(CASE WHEN ProductID = 1 AND BetType NOT IN (9,29,10) THEN 1 ELSE 0 END)
			,@isvalidSB_3rdSB = MAX(CASE WHEN ProductID IN (1,63,69) THEN 1 ELSE 0 END)
	FROM	dbo.SportBettypeMatrix WITH (NOLOCK)
	WHERE	BetType = @bettype
			AND ((ProductID = 1 
					--AND BetType NOT IN (9,29,10)
					AND bettype NOT BETWEEN 801 AND 899
				) OR ProductID IN (63,69)
			)
				
	SELECT	@isvalidSB = ISNULL(@isvalidSB,0)
			,@isvalidSB_3rdSB = ISNULL(@isvalidSB_3rdSB,0)

	IF @isvalidSB_3rdSB = 1 AND EXISTS (SELECT TOP 1 1 FROM dbo.CustWLMonitored_Setting c WITH(NOLOCK) WHERE c.recommend IN (@recommend, @mrecommend, @srecommend) AND c.custid IN (0, -1, @CustId))
	BEGIN		
		INSERT INTO dbo.WLMonitored_TicketDetails_Pending(TransId, CustId, Bettype, Actual_Stake, Winlost, aWinlost, mWinlost, sWinlost, SettlementTime)
		SELECT transid, custid, Bettype, actual_stake, winlost, aWinlost, mWinlost, sWinlost, ISNULL(SettlementTime, GETDATE())
		FROM inserted i
		WHERE	@statusID BETWEEN 111 AND 113 OR @statusID IN (102,103) 
	END

	IF @srecommend in ( 
		836203,--12BETSuperTB
		836226,--12BETSuperRMB
		932181,--AB88SuperTB
		932253,--AB88SuperRMB
		1574008,--MS88SuperRMB
		1574102,--MS88SuperIN
		2747989,--ALogSuperTB
		3167631,--12BETSuperINH
		3287311,--MS88SuperINH
		3293743,--TLCSuperRMB
		3752050,--MFSuperRMB
		4359240,--HAIFASuperRMB
		4833492,--AB88SuperINH
		6630778,--MacaubetSuperIN
		10566445,--AVIASuperRMB
		10580767,--W88SuperTB
		10580785,--W88SuperINH
		14373729,--KeenOceanSuperRMB
		14442433,--XTD3SuperRMB
		17126538,--GamingSoftSuperRMB
		17433116--NewhonbetSuperRMB
	) RETURN -- do not need to control TO for big licensee supers

	-- SUPER LIVE, tickets running in translog, then void/reject/refund
	IF (@bettype BETWEEN 801 AND 899) AND (@statusID NOT BETWEEN 101 AND 103)
		RETURN
	
	-- Process for sportbook bettype for TO Control only
	IF @isvalidSB = 0
	BEGIN
		RETURN;
	END

	INSERT INTO TOControl_TicketDetails_Insert (transid,bettype, statusID)
	VALUES (@TransID,@bettype, @statusID)
END 

GO