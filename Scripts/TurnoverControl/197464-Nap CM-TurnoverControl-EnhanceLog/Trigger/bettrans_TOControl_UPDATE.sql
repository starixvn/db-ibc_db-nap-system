/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
USE [bodb02]
GO

ALTER TRIGGER [dbo].[bettrans_TOControl_UPDATE]
   ON  [dbo].[bettrans]
   AFTER UPDATE
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
		- 20180625@Don: Tuning trigger - [Redmine:97313]
		- 20181219@Kan: TO Control add new Esport bet types - [Redmine: 106656]
		- 20190305@Razor: SMA TO Control - Integrate Bet Builder - [Redmine: 108391]
		- 20190701@Patrick: Enhance trigger update - [Redmine: #112219]
		- 20220711@July: Using sportbettypematrix to detect bettype of sportbook - [Redmine: 175141]
		- 20220520@Kathy: Alpha - My Monitor Accounts for Risk & Control [Redmine:170467]
		- 20221121@Kathy: Check setting when capture data [Redmine:#180716]
		- 20221215@Kathy: Monitor SMA win loss [Redmine:#179067]
		- 20231127@Max: Nap CM - Turnover Control - TO control service was running with a delay of approximately 1 hour [Redmine: #197464]
*/
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @n TINYINT
	DECLARE @srecommend INT, @statusid TINYINT, @bettype SMALLINT, @rowcount INT
	DECLARE @SettlementDate SMALLDATETIME
			,@isvalidSB BIT = 0
			,@isvalidSB_3rdSB BIT = 0
			,@isTOControl	BIT = 1

	DECLARE @tmpCustWLMonitored_Setting TABLE (TransId BIGINT, Recommend INT, mRecommend INT, Srecommend INT, CustId INT, Bettype SMALLINT, Actual_Stake MONEY, StatusId TINYINT
		, Winlost MONEY, aWinlost MONEY, mWinlost MONEY, sWinlost MONEY
		, SettlementTime DATETIME, WinlostDate SMALLDATETIME)

	SELECT TOP 2 @n = 1, @srecommend = srecommend, @statusid = statusid, @bettype = bettype
	FROM inserted

	SET @rowcount = @@ROWCOUNT

	SELECT	@isvalidSB = MAX(CASE WHEN ProductID = 1 AND BetType NOT IN (9,29,10) THEN 1 ELSE 0 END)
			,@isvalidSB_3rdSB = MAX(CASE WHEN ProductID IN (1,63,69) THEN 1 ELSE 0 END)
	FROM	dbo.SportBettypeMatrix WITH (NOLOCK)
	WHERE	BetType = @bettype
			AND ((ProductID = 1 
					AND bettype NOT BETWEEN 801 AND 899
				) OR ProductID IN (63,69)
			)

	SELECT	@isvalidSB = ISNULL(@isvalidSB,0)
			,@isvalidSB_3rdSB = ISNULL(@isvalidSB_3rdSB,0)

	IF @rowcount = 1
	BEGIN
		-- 101: reject; 102:void
		IF @statusid IN (101, 102) AND @srecommend IN ( 
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
		)
		BEGIN
			SET @isTOControl = 0
		END -- do not need to control TO for big licensee supers 
	END

	SELECT TOP 2 @n = 1
	FROM inserted

	IF @@ROWCOUNT > 1
	BEGIN
		IF (UPDATE(winlost) AND UPDATE(statusid) AND UPDATE(modds))
		BEGIN
			IF ((SELECT TOP 1 statusid FROM deleted) IN (0, 111, 112, 113)) -- just need to get top 1 from the batch because all tickets' status in one batch is the same
			BEGIN
				SET @isTOControl = 0 -- This is normal settment case, stake of ticket does not change ==> return
			END
		END
	END

	IF @isvalidSB = 0
	BEGIN
		SET @isTOControl = 0
	END

	IF @isTOControl = 1
	BEGIN
		INSERT INTO dbo.TOControl_TicketDetails_Update(TransId, StatusIDInserted, StatusIDDeleted)
		SELECT i.transid, i.statusID, d.statusID
		FROM inserted i
			INNER JOIN deleted d ON i.transid = d.transid
		WHERE i.betfrom <> 'p'
			AND i.SiteDBGroupID IN (0,3) --only process for credit
	END

	IF @isvalidSB_3rdSB = 1
	BEGIN
		INSERT INTO @tmpCustWLMonitored_Setting(TransId, sRecommend, mRecommend, Recommend, CustId, Bettype, Actual_Stake, StatusId, Winlost, aWinlost, mWinlost, sWinlost, SettlementTime, WinlostDate)
		SELECT	i.TransId, i.srecommend, i.mrecommend, i.recommend, i.custid, i.bettype, i.actual_stake, i.statusid, i.winlost, i.awinlost, i.mwinlost, i.swinlost, i.settlementtime, i.winlostdate
		FROM	inserted i
		WHERE	EXISTS (SELECT TOP 1 1 FROM dbo.CustWLMonitored_Setting c WITH(NOLOCK) WHERE c.recommend IN (i.srecommend, i.mrecommend, i.recommend) AND c.custid IN (0, -1, i.custid))

		IF @@ROWCOUNT > 0
		BEGIN
			SET @SettlementDate = CAST(GETDATE() AS DATE)

			INSERT INTO dbo.WLMonitored_TicketDetails_Pending (TransId, CustId, Bettype, Actual_Stake, Winlost, aWinlost, mWinlost, sWinlost, SettlementTime)
			SELECT i.transid, i.custid, i.bettype
					,CASE 
						WHEN d.statusID IN (0) 
							AND (i.statusID BETWEEN 111 AND 113 OR i.statusID IN (102, 103)) THEN i.actual_stake -- running to settle/void
						WHEN (d.statusID BETWEEN 111 AND 113 OR d.statusID IN (102, 103)) 
							AND (i.statusID BETWEEN 111 AND 113 OR i.statusID IN (102, 103)) THEN 0 -- settle/void to settle/void
						ELSE -d.actual_stake END -- settle/void to running
					,-d.winlost + i.winlost
					,-d.awinlost + i.aWinlost
					,-d.mwinlost + i.mWinlost
					,-d.swinlost + i.sWinlost
					,CASE WHEN i.SettlementTime = d.SettlementTime THEN GETDATE() ELSE ISNULL(i.SettlementTime, GETDATE()) END
			FROM @tmpCustWLMonitored_Setting i
				INNER JOIN deleted d
					ON i.transid = d.transid
			WHERE	(i.statusID <> d.statusID OR i.winlost <> d.winlost OR i.actual_stake <> d.actual_stake)
					AND (i.statusID BETWEEN 111 AND 113 OR i.statusID IN (0,102,103))
					AND (d.statusID BETWEEN 111 AND 113 OR d.statusID IN (0,102,103))
					AND (i.winlostdate >= @SettlementDate AND d.winlostdate >= @SettlementDate)
		END
	END 
	
END 
GO