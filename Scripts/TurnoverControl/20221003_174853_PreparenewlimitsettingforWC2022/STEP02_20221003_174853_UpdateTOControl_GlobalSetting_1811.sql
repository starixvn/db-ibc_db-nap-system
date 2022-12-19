/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20221003@July
	Task: SMA TO Control - Prepare new limit setting for World Cup 2022 - [Redmine: #174853]
	DB: DBCUST-CustDB

	Noted: Apply for soccer (no increase for OS)
	a) 789, 755555, Indo, IBCIndo: +300%        
	b) 733333,72222,222223: +250%        
	c) 76666B, 7aa666: +200%        
	d) XYZBET, Best-Odds, KORIBC: +0%        
	e) 611111: +0%
*/
USE CustDB 

GO
--STEP 2: UPDATE TOControl_GlobalSetting
DECLARE @maxcustid INT = xxxx

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
WHERE s.CustID <= @maxcustid

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
	SET s.MaxTurnOver = CASE WHEN c.site IN ('789y', '755555', 'Indo', 'IBCIndo') THEN s.MaxTurnOver * 4
							 WHEN c.site IN ('733333', '722222', '222223') THEN s.MaxTurnOver * 3.5
							 WHEN c.site IN ('76666B', '7aa666') THEN s.MaxTurnOver * 3
							 WHEN c.site IN ('XYZBET', 'Best-Odds', 'KORIBC') THEN s.MaxTurnOver * 1
							 WHEN c.site IN ('611111') THEN s.MaxTurnOver * 1
							 ELSE s.MaxTurnOver
						END
	FROM dbo.TOControl_GlobalSetting s WITH( ROWLOCK, UPDLOCK)
	INNER JOIN @ClearTOControl_GlobalSetting cto ON cto.CustID = s.CustID AND cto.Sporttype = s.Sporttype 
		AND cto.IsGroupHeadLine = s.IsGroupHeadLine AND cto.ProfileID = s.ProfileID
	INNER JOIN dbo.Customer c WITH (NOLOCK) ON s.CustID = c.custid
	WHERE s.CustID <= @maxcustid AND s.Sporttype = 1 --Apply for soccer

END

DROP TABLE #tblTOControl_GlobalSetting

GO
