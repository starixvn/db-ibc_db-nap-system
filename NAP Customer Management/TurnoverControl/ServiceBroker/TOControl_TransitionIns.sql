/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [sb].[TOControl_TransitionIns]
	@XMLString XML
AS 
/*
	Created: 20170324@Francis
	Task : Process message from SB queue to insert data into transition table
	DB: DBAGE.bodb02

	Original:

	Revisions:
		- 20170919@Helen: TO Control Phase 3 - [redmine:75557]
		- 20171110@Helen: Enhance performance for TO - [Redmine: 86052]
		- 20190708@Patrick: Move to DB052 - [Redmine:#112219]
		- 20191231@Malcolm : Separate setting and notification into Live/Non-Live and bettypes [Redmine: #126348]
		- 20200729@Max: SMA TO Control - change formula to use max Exposure when forecasting the risk - [Redmine: #136254]

	Param explanation:

	/*
	XML mapping dictionary tag when buliding and parsing XML string
	Tag		Stand_For
	---		---------
	s		srecommend
	m		mrecommend
	a		arecommend
	mid		matchid
	aTO		adjusted_TurnOver
	aHTO	adjusted_HouseTurnOver
	*/

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @TmpTable AS TABLE (srecommend INT, mrecommend INT, recommend INT,player INT, matchid INT,winlostdate SMALLDATETIME
								, adjusted_TurnOver MONEY,adjusted_TurnOver_withABS MONEY, adjusted_HTOWithoutExtraPT MONEY
								, adjusted_TurnOver_RM MONEY,adjusted_TurnOver_withABS_RM MONEY, adjusted_HTOWithoutExtraPT_RM MONEY
								, IsInsert BIT
								, IsMemberGroupHeadline BIT
								, bettype SMALLINT
								, liveindicator BIT
								)
	
	DECLARE @EventDate_min DATETIME
	
	CREATE TABLE #ExtraPTInfo (SuperID INT,ExtraPT DECIMAL(9,8), fromDate DATETIME, todate DATETIME)
	
	CREATE TABLE #GroupHeadline (CustID INT, GroupID INT, RoleID INT, IsMemberExcluded BIT, Sporttype SMALLINT)
	
	SET @EventDate_min = (SELECT MIN(eventdate) FROM bodb02.dbo.match m WITH(NOLOCK))
	
	BEGIN TRY
		INSERT INTO @TmpTable(srecommend, mrecommend, recommend,player, matchid, winlostdate, adjusted_TurnOver,adjusted_TurnOver_withABS, adjusted_HTOWithoutExtraPT
								, adjusted_TurnOver_RM,adjusted_TurnOver_withABS_RM, adjusted_HTOWithoutExtraPT_RM,IsInsert, bettype, liveindicator)
								
		SELECT x.v.value('(super/text())[1]','INT') AS srecommend,
			   x.v.value('(master/text())[1]','INT') AS mrecommend,
			   x.v.value('(agent/text())[1]','INT') AS recommend,
			   x.v.value('(player/text())[1]','INT') AS player,
			   x.v.value('(mid/text())[1]','INT') AS matchid,
			   x.v.value('(wld/text())[1]','SMALLDATETIME') AS winlostdate,
			   x.v.value('(adjTO/text())[1]','MONEY') AS adjusted_TurnOver,
			   x.v.value('(adjTOwithABS/text())[1]','MONEY') AS adjusted_TurnOver_withABS,
			   x.v.value('(adjHTONoExtraPT/text())[1]','MONEY') AS adjusted_HTOWithoutExtraPT,
			   x.v.value('(adjTO_RM/text())[1]','MONEY') AS adjusted_TurnOver_RM,
			   x.v.value('(adjTOwithABS_RM/text())[1]','MONEY') AS adjusted_TurnOver_withABS_RM,
			   x.v.value('(adjHTONoExtraPT_RM/text())[1]','MONEY') AS adjusted_HTOWithoutExtraPT_RM,
			   x.v.value('(IsInsert/text())[1]','BIT') AS IsInsert,
			   x.v.value('(bettype/text())[1]','SMALLINT') as bettype,
			   x.v.value('(liveindicator/text())[1]','BIT') as liveindicator
			   
		FROM @XMLString.nodes('/root/r') AS x(v)
		OPTION (OPTIMIZE FOR (@XMLString = NULL))
		
		-- Process for member belongs group headline for INSERT (data from dbtrans inserted to DB053) ONLY
		IF EXISTS (SELECT 1 FROM @TmpTable WHERE IsInsert = 1)
		BEGIN
			INSERT INTO @TmpTable (srecommend, mrecommend, recommend,player, matchid, winlostdate, adjusted_TurnOver,adjusted_TurnOver_withABS, adjusted_HTOWithoutExtraPT
									, adjusted_TurnOver_RM,adjusted_TurnOver_withABS_RM, adjusted_HTOWithoutExtraPT_RM,IsInsert,IsMemberGroupHeadline,bettype, liveindicator)
			SELECT srecommend, mrecommend, recommend,player, matchid, winlostdate, adjusted_TurnOver,adjusted_TurnOver_withABS, adjusted_HTOWithoutExtraPT
					, adjusted_TurnOver_RM,adjusted_TurnOver_withABS_RM, adjusted_HTOWithoutExtraPT_RM,IsInsert
					, 1 AS IsMemberGroupHeadline, bettype, liveindicator
			FROM @TmpTable tmp
			WHERE IsInsert = 1
				AND EXISTS (SELECT 1 FROM bodb02.dbo.custAccount ca WITH (NOLOCK) 
							WHERE tmp.player = ca.CustID)
			
			UPDATE	@TmpTable
				SET player = 0
			WHERE IsInsert = 1 AND IsMemberGroupHeadline IS NULL
				
		END	
		
		-- Get Extra PT Info: 
		-- Sportbook: Categorized by SubProduct =  '' , 'MG-SuperLive', 'MuayThai'. They are the same value. 
		-- So, only based on  conditions: Productid = 1, Sporttype = 0,SubProduct= '' 
		INSERT INTO #ExtraPTInfo (SuperID,ExtraPT,fromDate,todate)
		SELECT EPT.SuperId,EPT.ExtraPT,EPT.FromDate,EPT.ToDate
		FROM dbo.Acc_GroupExtraPTSetting EPT WITH (NOLOCK)
		WHERE EPT.ProductId = 1 AND EPT.Sporttype  = 0 
			AND EPT.SubProduct = '' AND EPT.ToDate >= @EventDate_min
			AND EXISTS (SELECT 1 FROM @TmpTable GHL WHERE GHL.srecommend = EPT.SuperId)
		
		-- Get Group Headline Info have global setting
		INSERT INTO #GroupHeadline (CustID,GroupID,RoleID,IsMemberExcluded,Sporttype)
		SELECT DISTINCT GS.CustID, ca.GroupID, ci.roleid
			, IsMemberExcluded =  CASE WHEN CI.roleid = 1 
											AND EXISTS (SELECT 1 FROM bodb02.dbo.custAccount CA1 WITH (NOLOCK)
														WHERE CA1.groupID = ca.GroupID AND CA1.custID IN (ci.srecommend, ci.mrecommend, ci.recommend))
										THEN 1 ELSE 0 END					
			, GS.Sporttype 
		FROM bodb02.dbo.CustGroupHeadline ca WITH (NOLOCK)
			INNER JOIN bodb02.dbo.custAccount ca1 WITH (NOLOCK) ON ca.GroupID = ca1.groupID
			INNER JOIN bodb02.dbo.Custinfo ci WITH (NOLOCK) ON ca.custID = ci.custid
			INNER JOIN bodb02.dbo.TOControl_GlobalSetting GS WITH (NOLOCK) ON ca.CustID = GS.CustID AND GS.IsGroupHeadLine = 1 AND gs.MaxTurnOver <> 0
			
		WHERE EXISTS (SELECT 1 FROM @TmpTable tmp  WHERE tmp.srecommend = ca1.CustID OR tmp.mrecommend = ca1.CustID OR tmp.recommend = ca1.CustID OR tmp.player = ca1.CustID) 
					
		-- Inserting data into TOControl_Transition
		INSERT INTO dbo.TOControl_Transition (CustID, matchid, adjusted_TurnOver, adjusted_HouseTurnOver,IsGroupHeadLine,liveindicator,bettype)
		-- For SMA Setting Level
		SELECT gl.CustID, t.matchid
		
				, SUM(t.adjusted_TurnOver ) AS adjusted_TurnOver
				
				, SUM (t.adjusted_HTOWithoutExtraPT - t.adjusted_TurnOver * ISNULL(ExtraPT_tmp.ExtraPT,0))	AS adjusted_HouseTurnOver
				
				, 0 AS IsGroupHeadLine
				, t.liveindicator AS  liveindicator
				, t.bettype
		FROM @TmpTable t
		    CROSS APPLY (
			             SELECT  DISTINCT glo.CustID, glo.IsGroupHeadLine, glo.Sporttype 
						 FROM TOControl_GlobalSetting glo WITH(NOLOCK) 
                         WHERE glo.CustID IN(t.srecommend,t.recommend,t.mrecommend) 
						       AND t.player = 0
							   AND glo.IsGroupHeadLine = 0
					    ) AS gl
			INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON t.matchid = m.matchid AND ((gl.Sporttype = 1 AND m.sporttype = 1) OR (gl.Sporttype = 99 AND m.sporttype > 1 AND m.sporttype <= 99))
			OUTER APPLY (SELECT SUM(s.ExtraPT) AS ExtraPT 
						 FROM #ExtraPTInfo s WITH(NOLOCK) 
						 WHERE t.srecommend = s.SuperId AND t.winlostdate BETWEEN s.FromDate AND s.ToDate ) AS ExtraPT_tmp
		GROUP BY gl.CustID, t.matchid, t.liveindicator, t.bettype
		
		-- For Headline Setting Level
		UNION ALL
		
		SELECT	gh.CustID, t.matchid
				
				, SUM(t.adjusted_TurnOver_RM ) AS adjusted_TurnOver
				
				, SUM (t.adjusted_HTOWithoutExtraPT_RM - t.adjusted_TurnOver_RM * ISNULL(ExtraPT_tmp.ExtraPT,0))	AS adjusted_HouseTurnOver
				
				, 1  AS IsGroupHeadLine
				, t.liveindicator AS  liveindicator
				, t.bettype
		FROM #GroupHeadline gh
			INNER JOIN bodb02.dbo.custAccount CA WITH (NOLOCK) ON CA.groupID = gh.GroupID
			INNER JOIN @TmpTable t ON 
									-- Headline is SMA
									(
										(t.srecommend = CA.CustID OR t.mrecommend = CA.CustID OR t.recommend = CA.CustID) AND t.player = 0
									) 
									-- member under this group headline
									OR (t.player = CA.custid AND ca.isGroupHeadline = 0)
									-- exclude member play group headline, and his super/master/agent under this group
									OR (t.player = CA.custid AND ca.isGroupHeadline = 1 AND gh.roleID = 1
										AND gh.IsMemberExcluded = 0)
			
			INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON t.matchid = m.matchid
							
			OUTER APPLY (SELECT SUM(s.ExtraPT) AS ExtraPT 
						 FROM #ExtraPTInfo s WITH(NOLOCK) 
						 WHERE t.srecommend = s.SuperId AND t.winlostdate BETWEEN s.FromDate AND s.ToDate ) AS ExtraPT_tmp
						 
		WHERE ((gh.Sporttype = 1 AND M.sporttype = 1) OR (gh.Sporttype = 99 AND m.sporttype > 1 AND m.sporttype <= 99))				 
		
		GROUP BY gh.CustID, t.matchid, t.liveindicator, t.bettype
		
			 
	END TRY
	BEGIN CATCH --Write ErrLog
		PRINT (ERROR_MESSAGE())
	END CATCH
	
	DROP TABLE #ExtraPTInfo
	DROP TABLE #GroupHeadline
	
END 