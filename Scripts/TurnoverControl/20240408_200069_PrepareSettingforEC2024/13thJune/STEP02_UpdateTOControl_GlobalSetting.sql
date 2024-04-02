/*<info serverAlias="DBCUST-CustDB" executers="" isFunction="0"></info>*/
/*
    Created: 20240408@July
	Task: SMA TO Control - Prepare Setting for EC 2024 - [Redmine: #200069]
	DB: DBCUST-CustDB

	Noted: EC24' TO Control Rule
		a) yUT, y789, y889, yOther, 755555, Indo, IBCIndo: +200%(current TO * 300%)        
		b) 733333, 722222, 222223: +150%( current TO * 250%)             
		c) 76666B, 7aa666: 200% (current TO * 300%)         
		d) XYZBET, Best-Odds, KORIBC, 611111, 777777, 7a5555: +0%    
*/
USE CustDB 

GO
--STEP 2: UPDATE TOControl_GlobalSetting
DECLARE @maxCustID INT = xxxx

DECLARE @ClearTOControl_GlobalSetting AS TABLE (CustID INT, MaxTurnOver MONEY, Sporttype SMALLINT, IsGroupHeadLine BIT, ProfileID SMALLINT, IsGlobalLockTOLimit BIT)
CREATE TABLE #tblTOControl_GlobalSetting
(
	CustID INT,
	MaxTurnOver MONEY,
	Sporttype SMALLINT,
	IsGroupHeadLine BIT,
	ProfileID SMALLINT,
	IsGlobalLockTOLimit BIT,
	IsFinishUpdateGlobalSetting BIT

)
CREATE CLUSTERED INDEX CIX_tblTOControl_GlobalSetting ON #tblTOControl_GlobalSetting (CustID, Sporttype, IsGroupHeadLine, ProfileID)

INSERT INTO #tblTOControl_GlobalSetting (CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit)
SELECT CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit
FROM dbo.TOControl_GlobalSetting_History_tmp s WITH(NOLOCK)
WHERE s.CustID <= @maxCustID

WHILE (1 = 1)
BEGIN
	DELETE @ClearTOControl_GlobalSetting

	UPDATE TOP(5000) t
			SET IsFinishUpdateGlobalSetting = 1
	OUTPUT DELETED.CustID
		 , DELETED.MaxTurnOver
		 , DELETED.Sporttype
		 , DELETED.IsGroupHeadLine
		 , DELETED.ProfileID
		 , DELETED.IsGlobalLockTOLimit
	INTO @ClearTOControl_GlobalSetting  (CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit)
	FROM #tblTOControl_GlobalSetting t 
		WHERE IsFinishUpdateGlobalSetting IS NULL
	
	IF @@ROWCOUNT = 0 BREAK
	
	UPDATE s
	SET s.MaxTurnOver = CASE WHEN c.site IN ('yUT', 'y789', 'y889', 'yOther', '755555', 'Indo', 'IBCIndo') THEN s.MaxTurnOver * 3
							 WHEN c.site IN ('733333', '722222', '222223') THEN s.MaxTurnOver * 2.5
							 WHEN c.site IN ('76666B', '7aa666') THEN s.MaxTurnOver * 3
							 WHEN c.site IN ('XYZBET', 'Best-Odds', 'KORIBC', '611111', '777777', '7a5555') THEN s.MaxTurnOver * 1
							 ELSE s.MaxTurnOver
						END
	FROM dbo.TOControl_GlobalSetting s WITH( ROWLOCK, UPDLOCK)
	INNER JOIN @ClearTOControl_GlobalSetting cto ON cto.CustID = s.CustID AND cto.Sporttype = s.Sporttype 
		AND cto.IsGroupHeadLine = s.IsGroupHeadLine AND cto.ProfileID = s.ProfileID
	INNER JOIN dbo.Customer c WITH (NOLOCK) ON s.CustID = c.custid
	WHERE s.CustID <= @maxCustID

	WAITFOR DELAY '00:00:00.280'

END

DROP TABLE #tblTOControl_GlobalSetting

GO
