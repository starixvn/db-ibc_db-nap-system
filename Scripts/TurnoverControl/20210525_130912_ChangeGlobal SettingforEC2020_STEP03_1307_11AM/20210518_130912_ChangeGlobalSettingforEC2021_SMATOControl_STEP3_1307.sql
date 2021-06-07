/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210504@July
	Task: SMA TO Control - Change Global Setting for EC2021 - [Redmine: #130912]
	DB: DBCUST-CustDB
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
	INNER JOIN dbo.Customer c WITH (NOLOCK) ON s.CustID = c.custid
	INNER JOIN dbo.Customer sp WITH (NOLOCK) ON sp.CustID = c.srecommend
	WHERE 
		1 = CASE 
				WHEN c.site = '611111' AND sp.username IN ('2CU','A312D','A312E','A312RMB','BAK','D312RMB','DC1','DC2','FBH','FNH'
							,'FNN','HK09','HK8A','JK1','LHK','LHR','MC','MC5','MG1','MKE'
							,'MOX','MVP','POR','POW','POY','PPB','PPR','PYA','PYB','PYH'
							,'Pyy','RGRMB','RGRMB2','RW01','RW02','RW03','RW05','RW06','RW07','RW08'
							,'RW09','RW10','RW11','S123R','S312A','S312K','S31BRMB','S56A','S56AE','S56AF'
							,'S69H','s6cn','S80R','S81R','S863R','S90R','S99RB','SBRR','SBV','SBZB'
							,'SBZC','SBZR','SF8','SFB','SME','SMQ','SMW','SSFK','SWK','SWKH'
							,'TEH','TEK','TEP','THG','THR','THS','WKR','WPR','XCN'
					      ) /*site 611111 except the 79 supers*/ 
					THEN 0
				ELSE 1
			END	
END

DROP TABLE #tblTOControl_GlobalSetting_History_tmp

