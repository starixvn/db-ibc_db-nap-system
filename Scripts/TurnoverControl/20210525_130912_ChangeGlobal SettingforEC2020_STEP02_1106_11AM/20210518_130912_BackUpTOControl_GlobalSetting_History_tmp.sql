/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210504@July
	Task: SMA TO Control - Change Global Setting for EC2021 - [Redmine: #130912]
	DB: DBCUST-CustDB
*/

USE CustDB 

GO
--STEP 1: script to save all current data into new physical TOControl_GlobalSetting-> TOControl_GlobalSetting_History_tmp
DECLARE @maxcustid INT = NULL

CREATE TABLE #tblTOControl_GlobalSetting
(
	CustID INT,
	MaxTurnOver MONEY,
	Sporttype SMALLINT,
	IsGroupHeadLine BIT,
	ProfileID SMALLINT,
	IsGlobalLockTOLimit BIT,
	IsFinishHistory BIT,

)

INSERT INTO #tblTOControl_GlobalSetting (CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit)
SELECT CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit
FROM dbo.TOControl_GlobalSetting s WITH(NOLOCK)
WHERE s.CustID <= @maxcustid

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

DROP TABLE #tblTOControl_GlobalSetting
GO