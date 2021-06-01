/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210504@July
	Task: SMA TO Control - Change Global Setting for EC2021 - [Redmine: #130912]
	DB: DBCUST-CustDB
*/

USE CustDB 

GO
--STEP 2: UPDATE TOControl_GlobalSetting
DECLARE @maxcustid INT = NULL
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

INSERT INTO #tblTOControl_GlobalSetting (CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit)
SELECT CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit
FROM dbo.TOControl_GlobalSetting s WITH(NOLOCK)
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
	SET s.MaxTurnOver = CASE WHEN c.site IN ('789y', '755555', 'Indo', 'IBCIndo', '611111') THEN s.MaxTurnOver * 3
							 WHEN c.site IN ('733333', '72222', '222223') THEN s.MaxTurnOver * 2.5
							 WHEN c.site IN ('76666B', '7aa666') THEN s.MaxTurnOver * 2
							 END
	FROM dbo.TOControl_GlobalSetting s WITH( ROWLOCK, UPDLOCK)
	INNER JOIN @ClearTOControl_GlobalSetting cto ON cto.CustID = s.CustID AND cto.Sporttype = s.Sporttype 
		AND cto.IsGroupHeadLine = s.IsGroupHeadLine AND cto.ProfileID = s.ProfileID
	INNER JOIN dbo.Customer c WITH (NOLOCK) ON s.CustID = c.custid
	WHERE c.username NOT IN ('2CU','A312D','A312E','A312RMB','BAK','D312RMB','DC1','DC2','FBH','FNH'
							,'FNN','HK09','HK8A','JK1','LHK','LHR','MC','MC5','MG1','MKE'
							,'MOX','MVP','POR','POW','POY','PPB','PPR','PYA','PYB','PYH'
							,'Pyy','RGRMB','RGRMB2','RW01','RW02','RW03','RW05','RW06','RW07','RW08'
							,'RW09','RW10','RW11','S123R','S312A','S312K','S31BRMB','S56A','S56AE','S56AF'
							,'S69H','s6cn','S80R','S81R','S863R','S90R','S99RB','SBRR','SBV','SBZB'
							,'SBZC','SBZR','SF8','SFB','SME','SMQ','SMW','SSFK','SWK','SWKH'
							,'TEH','TEK','TEP','THG','THR','THS','WKR','WPR','XCN'
					      ) /*site 611111 except the 79 supers*/
END

DROP TABLE #tblTOControl_GlobalSetting

GO
