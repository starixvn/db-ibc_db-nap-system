/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20221003@July
	Task: SMA TO Control - Prepare new limit setting for World Cup 2022 - [Redmine: #174853]
	DB: DBCUST-CustDB

	Noted: Apply for soccer (no increase for OS)
*/


USE CustDB 
GO

--STEP 1: update all data exists TOControl_GlobalSetting <-> TOControl_GlobalSetting_History_tmp
CREATE TABLE #tblTOControl_GlobalSetting_History_tmp
(
	CustID INT,
	MaxTurnOver MONEY,
	Sporttype SMALLINT,
	IsGroupHeadLine BIT,
	ProfileID SMALLINT,
	IsGlobalLockTOLimit BIT,
	IsFinishHistory BIT

)
CREATE CLUSTERED INDEX CIX_tblTOControl_GlobalSetting_History_tmp ON #tblTOControl_GlobalSetting_History_tmp (CustID, Sporttype, IsGroupHeadLine, ProfileID)

DECLARE @ClearTOControl_GlobalSettingHistory_tmp AS TABLE (CustID INT, MaxTurnOver MONEY, Sporttype SMALLINT, IsGroupHeadLine BIT, ProfileID SMALLINT, IsGlobalLockTOLimit BIT)

INSERT INTO #tblTOControl_GlobalSetting_History_tmp (CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit)
SELECT CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit
FROM dbo.TOControl_GlobalSetting_History_tmp s WITH(NOLOCK)

WHILE (1 = 1)
BEGIN
	DELETE @ClearTOControl_GlobalSettingHistory_tmp

	UPDATE TOP(5000) t
			SET IsFinishHistory = 1
	OUTPUT DELETED.CustID
		 , DELETED.MaxTurnOver
		 , DELETED.Sporttype
		 , DELETED.IsGroupHeadLine
		 , DELETED.ProfileID
		 , DELETED.IsGlobalLockTOLimit
	INTO @ClearTOControl_GlobalSettingHistory_tmp  (CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit)
	FROM #tblTOControl_GlobalSetting_History_tmp t 
		WHERE IsFinishHistory IS NULL
	
	IF @@ROWCOUNT = 0 BREAK
	
	UPDATE s
	SET  s.MaxTurnOver = sh.MaxTurnOver
	FROM dbo.TOControl_GlobalSetting s WITH(ROWLOCK, UPDLOCK)
		 INNER JOIN @ClearTOControl_GlobalSettingHistory_tmp sh
		 ON s.CustID = sh.CustID AND s.Sporttype = sh.Sporttype 
			AND s.IsGroupHeadLine = sh.IsGroupHeadLine AND s.ProfileID = sh.ProfileID
	WHERE s.Sporttype = 1
END

DROP TABLE #tblTOControl_GlobalSetting_History_tmp

