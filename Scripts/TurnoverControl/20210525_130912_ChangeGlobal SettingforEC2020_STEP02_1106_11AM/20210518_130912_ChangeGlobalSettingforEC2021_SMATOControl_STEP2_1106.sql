/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210504@July
	Task: SMA TO Control - Change Global Setting for EC2021 - [Redmine: #130912]
	DB: DBCUST-CustDB
*/

USE CustDB 

GO
--STEP 1: script to save all current data into new physical TOControl_GlobalSetting-> TOControl_GlobalSetting_History_tmp
CREATE TABLE #tblTOControl_GlobalSetting
(
	CustID INT,
	MaxTurnOver MONEY,
	Sporttype SMALLINT,
	IsGroupHeadLine BIT,
	ProfileID SMALLINT,
	IsGlobalLockTOLimit BIT,
	IsFinishHistory BIT,
	IsFinishUpdateGlobalSetting BIT

)
DECLARE @ClearTOControl_GlobalSetting AS TABLE (CustID INT, MaxTurnOver MONEY, Sporttype SMALLINT, IsGroupHeadLine BIT, ProfileID SMALLINT, IsGlobalLockTOLimit BIT)

INSERT INTO #tblTOControl_GlobalSetting (CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit)
SELECT CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit
FROM dbo.TOControl_GlobalSetting s WITH(NOLOCK)

WHILE (1=1)
BEGIN

	UPDATE TOP(5000) t
			SET IsFinishHistory = 1
	OUTPUT DELETED.CustID
		 , DELETED.MaxTurnOver
		 , DELETED.Sporttype
		 , DELETED.IsGroupHeadLine
		 , DELETED.ProfileID
		 , DELETED.IsGlobalLockTOLimit
	INTO dbo.TOControl_GlobalSetting_History_tmp (CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit)
	FROM #tblTOControl_GlobalSetting t 
		WHERE IsFinishHistory IS NULL

	IF @@ROWCOUNT = 0 BREAK
END


--STEP 2: update TOControl_GlobalSetting * 3
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
	SET s.MaxTurnOver = CASE WHEN c.site IN ('789y', '755555', 'Indo', 'IBCIndo', '611111') THEN s.MaxTurnOver * 3
							 WHEN c.site IN ('733333', '72222', '222223') THEN s.MaxTurnOver * 2.5
							 WHEN c.site IN ('76666B', '7aa666') THEN s.MaxTurnOver * 2
							 END
	FROM dbo.TOControl_GlobalSetting s WITH( ROWLOCK, UPDLOCK)
	INNER JOIN @ClearTOControl_GlobalSetting cto ON cto.CustID = s.CustID AND cto.Sporttype = s.Sporttype 
		AND cto.IsGroupHeadLine = s.IsGroupHeadLine AND cto.ProfileID = s.ProfileID
	INNER JOIN dbo.Customer c WITH (NOLOCK) ON s.CustID = c.custid
END

DROP TABLE #tblTOControl_GlobalSetting


