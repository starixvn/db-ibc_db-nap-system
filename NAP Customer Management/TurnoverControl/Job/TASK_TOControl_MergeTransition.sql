/*<info serverAlias="DBCUST-CustDB" executers="" viewers="" isFunction="0"></info>*/
USE [CustDB]
GO
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

Param explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @PercentageUsed MONEY

	CREATE TABLE #TmpTableRaw(RowId BIGINT, CustID INT, matchid INT, adjusted_TurnOver MONEY, adjusted_HouseTurnOver MONEY,IsGroupHeadline BIT,sporttype SMALLINT)
	
	CREATE TABLE #TmpTable(CustID INT, matchid INT, adjusted_TurnOver MONEY, adjusted_HouseTurnOver MONEY, MaxTurnOver MONEY NULL, IsGroupHeadline BIT,sporttype SMALLINT)
	
	CREATE CLUSTERED INDEX CIX_CustID_MatchID ON #TmpTableRaw (CustID, matchid, IsGroupHeadline, sporttype)
	CREATE UNIQUE CLUSTERED INDEX CIX_CustID_MatchID ON #TmpTable (CustID, matchid, IsGroupHeadline, sporttype)

	--get rowversion
	DECLARE @__lastRowId BIGINT, @__maxRowId BIGINT
	SELECT @__lastRowId = CONVERT(BIGINT, VValue)
	FROM dbo.TOConTrol_GlobalVariables WITH (ROWLOCK)
	WHERE VName = 'MaxID'

	INSERT INTO #TmpTableRaw(RowId, CustID, matchid, adjusted_TurnOver
		, adjusted_HouseTurnOver, IsGroupHeadline, sporttype)
	EXEC DBEXT.bodb02.dbo.TASK_TOControl_GetTransition @RowId = @__lastRowId

	IF @@ROWCOUNT = 0
		RETURN

	INSERT INTO #TmpTable(CustID, matchid, IsGroupHeadline, sporttype, adjusted_TurnOver, adjusted_HouseTurnOver)
	SELECT CustID, matchid,IsGroupHeadline, sporttype, SUM (adjusted_TurnOver), SUM(adjusted_HouseTurnOver)
	FROM #TmpTableRaw
	GROUP BY CustID, matchid, IsGroupHeadline, sporttype

	UPDATE t 
		SET MaxTurnOver = gl.MaxTurnOver
	FROM #TmpTable t
		INNER JOIN dbo.TOControl_GlobalSetting gl WITH (NOLOCK) ON t.CustID = gl.CustID 
							AND t.IsGroupHeadline = gl.IsGroupHeadLine 
							AND ((gl.Sporttype = 1 AND t.sporttype = 1) OR (gl.Sporttype = 99 AND t.sporttype > 1 AND t.sporttype <= 99))								
	
	DELETE #TmpTable WHERE MaxTurnOver IS NULL
		
	MERGE dbo.TOControl_Setting AS TARGET
			USING (SELECT CustID, matchid, MaxTurnOver, adjusted_TurnOver, adjusted_HouseTurnOver,IsGroupHeadLine FROM #TmpTable)
			   AS SOURCE (CustID, matchid, MaxTurnOver, adjusted_TurnOver, adjusted_HouseTurnOver,IsGroupHeadLine)
				ON (TARGET.CustID = SOURCE.CustID AND TARGET.matchid = SOURCE.matchid AND TARGET.IsGroupHeadLine = SOURCE.IsGroupHeadLine)
			WHEN MATCHED THEN 
				 UPDATE SET 
							--@PercentageUsed = CASE WHEN TARGET.MaxTurnOver = 0 THEN	100 ELSE (TARGET.HouseTurnover + SOURCE.adjusted_HouseTurnOver) * 100 / TARGET.MaxTurnOver END,
							TARGET.TotalTurnOver = TARGET.TotalTurnOver + SOURCE.adjusted_TurnOver,
							TARGET.HouseTurnover = TARGET.HouseTurnover + SOURCE.adjusted_HouseTurnOver,
							
							TARGET.PercentLevel = CASE WHEN TARGET.MaxTurnOver = 0 THEN	10 
														ELSE ISNULL((SELECT MAX(PercentLevel) 
																	FROM dbo.TOControl_LevelSetting WITH (NOLOCK) 
																	WHERE (TARGET.HouseTurnover + SOURCE.adjusted_HouseTurnOver) * 100 / TARGET.MaxTurnOver >= PercentValue
														  
																	),0)
													END				
								
			WHEN NOT MATCHED THEN	
				INSERT (CustID, matchid, IsGroupHeadLine, MaxTurnOver, TotalTurnOver, HouseTurnover, IsNotified, PercentLevel)
				VALUES (SOURCE.CustID, SOURCE.matchid,SOURCE.IsGroupHeadLine, SOURCE.MaxTurnOver, SOURCE.adjusted_TurnOver, SOURCE.adjusted_HouseTurnOver, 0, 
						CASE WHEN SOURCE.MaxTurnOver = 0 THEN 10 
							ELSE ISNULL((SELECT MAX(PercentLevel) 
										FROM dbo.TOControl_LevelSetting WITH (NOLOCK) 
										WHERE (SOURCE.adjusted_HouseTurnOver) * 100 / SOURCE.MaxTurnOver  >= PercentValue),0)
						END				
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