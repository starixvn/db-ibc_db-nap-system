/*<info serverAlias="DB053-bodb02" executers="" isFunction="0"></info>*/
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
*/
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @n TINYINT
	DECLARE @srecommend INT, @statusid TINYINT, @bettype SMALLINT
	DECLARE @isvalid BIT = 0
	SELECT TOP 2 @n = 1, @srecommend = srecommend, @statusid = statusid, @bettype = bettype
	FROM inserted

	IF @@ROWCOUNT = 1
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
		) RETURN -- do not need to control TO for big licensee supers 
	END

	SELECT TOP 2 @n = 1
	FROM inserted

	IF @@ROWCOUNT > 1
		IF (UPDATE(winlost) AND UPDATE(statusid) AND UPDATE(modds))
			IF ((SELECT TOP 1 statusid FROM deleted) IN (0, 111, 112, 113)) -- just need to get top 1 from the batch because all tickets' status in one batch is the same
				RETURN -- This is normal settment case, stake of ticket does not change ==> return
	
	SET @isvalid = (SELECT TOP 1 1  
					FROM dbo.SportBettypeMatrix WITH (NOLOCK)
					WHERE ProductID = 1 AND BetType = @bettype
					 AND BetType NOT IN (9,29,10)
					 )
	IF @isvalid = 0
	BEGIN
		RETURN;
	END

	INSERT INTO dbo.TOControl_TicketDetails_Update(TransId, StatusIDInserted, StatusIDDeleted)
	SELECT i.transid, i.statusID, d.statusID
	FROM inserted i
		INNER JOIN deleted d ON i.transid = d.transid
	WHERE i.betfrom <> 'p'
	
END 
GO