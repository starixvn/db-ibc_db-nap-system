/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TASK_TOControl_MergeTransition]
AS 
/*
Created: 20170324@Francis
Task : Merge changed data for TOControl_Setting
DB: DBCUST.CustDB

Original:

Revisions:
	- 20170920@Helen: TO Control Phase 3 - [Redmine: 75557]
	- 20190708@Patrick: Move to DB052 [Redmine: #112219]
	- 20190927@Helen: Differentiate alert thresholds between MBC and CN88 [Redmine: #119561]
	- 20191231@Malcolm : Separate setting and notification into Live/Non-Live and bettypes [Redmine: #126348]
	- 20200122@Max: Support Separate setting and notification into Live/Non-Live major and minor bettypes [Redmine: #126841]
	- 20200720@Helen: SMA TO Control - change formula to use max Exposure when forecasting the risk - [Redmine: #136254]
	- 20211221@July: Change the link server name from DBEXT to DBTOC - [Redmine: #166411]
	- 20231127@Max: Nap CM - Turnover Control - TO control service was running with a delay of approximately 1 hour [Redmine: #197464]

Param explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @PercentageUsed MONEY, @MaxLevel TINYINT
	
	SET @MaxLevel = (SELECT TOP 1 PercentLevel FROM dbo.TOControl_LevelSetting WITH (NOLOCK) WHERE PercentValue = 100)
	
	CREATE TABLE #TmpTableRaw(RowId BIGINT, CustID INT, matchid INT, adjusted_TurnOver MONEY, adjusted_HouseTurnOver MONEY,IsGroupHeadline BIT,sporttype SMALLINT, liveindicator BIT, bettype SMALLINT)
	
	CREATE TABLE #TmpTable(CustID INT, matchid INT, adjusted_TurnOver MONEY, adjusted_HouseTurnOver MONEY, MaxTurnOver MONEY NULL, IsGroupHeadline BIT,sporttype SMALLINT, ProfileID SMALLINT, IsGlobalLockTOLimit BIT)
	
	CREATE CLUSTERED INDEX CIX_CustID_MatchID ON #TmpTableRaw (CustID, matchid, IsGroupHeadline, sporttype, bettype, liveindicator)
	CREATE UNIQUE CLUSTERED INDEX CIX_CustID_MatchID ON #TmpTable (CustID, matchid, IsGroupHeadline, sporttype, ProfileID)

	--get rowversion
	DECLARE @__lastRowId BIGINT, @__maxRowId BIGINT
	SELECT @__lastRowId = CONVERT(BIGINT, VValue)
	FROM dbo.TOConTrol_GlobalVariables WITH (ROWLOCK)
	WHERE VName = 'MaxID'

	INSERT INTO #TmpTableRaw(RowId, CustID, matchid, adjusted_TurnOver
		, adjusted_HouseTurnOver, IsGroupHeadline, sporttype, liveindicator, bettype)
	EXEC DBTOC.bodb02.dbo.TASK_TOControl_GetTransition @RowId = @__lastRowId

	IF @@ROWCOUNT = 0
		RETURN

	--Capture all data get from output of TASK_TOControl_GetTransition (TOControl_Transition)
	INSERT INTO dbo.TOControl_TransitionProcessedLog (MinRowId, MaxRowId)
	SELECT MIN(t.RowId), MAX(t.RowId)
	FROM #TmpTableRaw t

	INSERT INTO #TmpTable(CustID, matchid, IsGroupHeadline, sporttype, ProfileID , adjusted_TurnOver, adjusted_HouseTurnOver)
	SELECT t1.CustID, matchid,IsGroupHeadline, spt.sporttype, pf.profileID
		, SUM (adjusted_TurnOver), SUM(adjusted_HouseTurnOver)
	FROM #TmpTableRaw t1
		CROSS APPLY (SELECT CASE WHEN t1.sporttype = 1 THEN 1 
								 WHEN t1.sporttype > 1 AND t1.sporttype <= 99 THEN 99
							END as sporttype) AS spt
		CROSS APPLY (SELECT TOP 1 profileID
					 FROM dbo.TOControl_ProfileSetting t2 WITH (NOLOCK)
					 WHERE  t2.Sporttype = spt.sporttype 
							AND T1.liveindicator = T2.liveindicator
							AND t2.bettype IN (t1.bettype,0)
					 ORDER BY t2.bettype DESC		 
					 )AS pf
	GROUP BY t1.CustID, t1.matchid, t1.IsGroupHeadline, spt.sporttype,pf.profileID


	UPDATE t 
		SET MaxTurnOver = gl.MaxTurnOver, IsGlobalLockTOLimit = gl.IsGlobalLockTOLimit
	FROM #TmpTable t
		INNER JOIN dbo.TOControl_GlobalSetting gl WITH (NOLOCK) ON t.CustID = gl.CustID 
							AND t.IsGroupHeadline = gl.IsGroupHeadLine 
							AND t.ProfileID = gl.ProfileID
							AND t.sporttype = gl.Sporttype								
	
	DELETE #TmpTable WHERE MaxTurnOver IS NULL
		
	MERGE dbo.TOControl_Setting AS TARGET
			USING (SELECT CustID, matchid, MaxTurnOver, adjusted_TurnOver, adjusted_HouseTurnOver,IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit FROM #TmpTable)
			   AS SOURCE (CustID, matchid, MaxTurnOver, adjusted_TurnOver, adjusted_HouseTurnOver,IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit)
				ON (TARGET.CustID = SOURCE.CustID AND TARGET.matchid = SOURCE.matchid AND TARGET.IsGroupHeadLine = SOURCE.IsGroupHeadLine AND TARGET.ProfileID = SOURCE.ProfileID)
			WHEN MATCHED THEN 
				 UPDATE SET 
							--@PercentageUsed = CASE WHEN TARGET.MaxTurnOver = 0 THEN	100 ELSE (TARGET.HouseTurnover + SOURCE.adjusted_HouseTurnOver) * 100 / TARGET.MaxTurnOver END,
							TARGET.TotalTurnOver = TARGET.TotalTurnOver + SOURCE.adjusted_TurnOver,
							TARGET.HouseTurnover = TARGET.HouseTurnover + SOURCE.adjusted_HouseTurnOver,
							
							TARGET.PercentLevel = CASE WHEN TARGET.MaxTurnOver = 0 THEN	@MaxLevel 
														ELSE ISNULL((SELECT MAX(PercentLevel) 
																	FROM dbo.TOControl_LevelSetting WITH (NOLOCK) 
																	WHERE ABS((TARGET.HouseTurnover + SOURCE.adjusted_HouseTurnOver)) * 100 / TARGET.MaxTurnOver >= PercentValue
														  
																	),0)
													END,
							TARGET.IsGlobalLockTOLimit = SOURCE.IsGlobalLockTOLimit,
							TARGET.ModifiedDate = GETDATE()
								
			WHEN NOT MATCHED THEN	
				INSERT (CustID, matchid, IsGroupHeadLine, MaxTurnOver, TotalTurnOver, HouseTurnover, IsNotified, PercentLevel, ProfileID, IsGlobalLockTOLimit)
				VALUES (SOURCE.CustID, SOURCE.matchid,SOURCE.IsGroupHeadLine, SOURCE.MaxTurnOver, SOURCE.adjusted_TurnOver, SOURCE.adjusted_HouseTurnOver, 0, 
						CASE WHEN SOURCE.MaxTurnOver = 0 THEN @MaxLevel 
							ELSE ISNULL((SELECT MAX(PercentLevel) 
										FROM dbo.TOControl_LevelSetting WITH (NOLOCK) 
										WHERE ABS((SOURCE.adjusted_HouseTurnOver)) * 100 / SOURCE.MaxTurnOver  >= PercentValue),0)
						END, SOURCE.ProfileID, SOURCE.IsGlobalLockTOLimit				
						);
						
	IF @@ERROR = 0
	BEGIN
		
		SELECT @__maxRowId = MAX(RowId) FROM #TmpTableRaw

		UPDATE dbo.TOConTrol_GlobalVariables WITH (UPDLOCK, ROWLOCK)
		SET VValue = CONVERT(VARCHAR(200), @__maxRowId)
		WHERE VName = 'MaxID'
	END

	DROP TABLE #TmpTableRaw
	DROP TABLE #TmpTable
END
GO