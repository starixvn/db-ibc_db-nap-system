/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [sb].[TOControl_ProcessData]
AS
/*
	Create By: Don
	Created Date: 2017-03-22
	Task: Apply Service Broker for Turnover Control function
	DB: DBAGE.bodb02 
		
	Revision
		- 20180622@Don: Tuning trigger - [Redmine:97313]
		- 20180626@Helen: Tuning trigger - [Redmine:97442]
		- 20181219@Kan: TO Control add new Esport bet types - [Redmine: 106656]
		- 20190305@Razor: SMA TO Control - Integrate Bet Builder - [Redmine: 108391]
		- 20190701@Patrick: Enhance trigger update [Redmine: #112219]
		- 20191231@Malcolm : Separate setting and notification into Live/Non-Live and bettypes [Redmine: #126348]
		- 20200714@Max: SMA TO Control - Add block increasing TO Limit feature to specific SMAs - [Redmine: #136254]
		- 20200720@Helen: SMA TO Control - change formula to use max Exposure when forecasting the risk - [Redmine: #136254]
		- 20220711@July: Using sportbettypematrix to detect bettype of sportbook - [Redmine: 175141]
		
	Param's explaination
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @FunctionName VARCHAR(100) = 'TOControl'

	DECLARE @xml_TOControl XML = ''
	
	DECLARE @handle UNIQUEIDENTIFIER
	
	DECLARE @i INT, @countDeleted INT
	
	DECLARE @ReceiveMax INT, @timeout INT, @IsExistingTarget BIT
	
	DECLARE @message_type_name NVARCHAR(256)
	
	SELECT TOP 1 @ReceiveMax = ISNULL(MaxReceiveMsg, 1)
			   , @timeout = ISNULL(MaxReceiveTimeOut, 0)
			   , @IsExistingTarget = ISNULL(IsExistingTarget, 0)
	FROM sb.ConfigurationReference	WITH (NOLOCK) 
	WHERE FunctionName = @FunctionName	
	
	DECLARE @Messages TABLE (conversation_handle UNIQUEIDENTIFIER, message_type_name NVARCHAR(256), message_body XML)
	DECLARE @EndDialogMessages TABLE 
	(
		ID INT IDENTITY(1, 1) PRIMARY KEY, 
		conversation_handle UNIQUEIDENTIFIER, 
		message_type_name NVARCHAR(256), 
		message_body XML
	)

	DECLARE @tblTransId AS TABLE (TransId BIGINT, Bettype SMALLINT, IsInsert BIT, statusID TINYINT, statusIDDeleted TINYINT)
	
	DECLARE @tblMsg AS TABLE (
		super INT, [master] INT, agent INT, player INT,
		mid INT, wld SMALLDATETIME, 
		adjTO MONEY, adjTO_Exposure MONEY, adjHTONoExtraPT MONEY, adjTO_RM MONEY, adjTO_Exposure_RM MONEY, adjHTONoExtraPT_RM MONEY, IsInsert BIT, bettype smallint, liveindicator bit)
	 
	WAITFOR (RECEIVE TOP (@ReceiveMax)
					conversation_handle,
					message_type_name, 
					message_body
			FROM Queue_TOControl_DBAGE
			INTO @Messages ), TIMEOUT @timeout;
			
	IF (@@ROWCOUNT = 0)
		RETURN
		
	DELETE FROM @Messages
	OUTPUT DELETED.conversation_handle
		 , DELETED.message_type_name
		 , DELETED.message_body	
	INTO @EndDialogMessages
	WHERE message_type_name IN ('http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
							  , 'http://schemas.microsoft.com/SQL/ServiceBroker/Error')	
	
	SET @countDeleted = @@ROWCOUNT
	
	IF @countDeleted > 0
	BEGIN
		SELECT TOP 1 @handle = conversation_handle
		FROM @EndDialogMessages
		
		END CONVERSATION @handle WITH CLEANUP;
	END			
	
	SELECT TOP 1 
		   @handle = conversation_handle
		 , @message_type_name = message_type_name
	FROM @Messages						  						  
	
	IF @message_type_name IN ('MessageType_TOControl_Single','MessageType_TOControl_Multiple')
	BEGIN
		
		IF @message_type_name = 'MessageType_TOControl_Single'
		BEGIN
			INSERT INTO @tblTransId(TransId, Bettype, IsInsert,statusID)
			SELECT msd.TransId,msd.Bettype,msd.IsInsert, msd.statusID
			FROM @Messages m
				CROSS APPLY (SELECT x.v.value('(TransId/text())[1]','BIGINT') AS TransId,
								   x.v.value('(statusID/text())[1]','TINYINT') AS statusID,
								   x.v.value('(IsInsert/text())[1]','BIT') AS IsInsert,
								   x.v.value('(Bettype/text())[1]','SMALLINT') AS Bettype
							 FROM m.message_body.nodes('/r') AS x(v)
							) msd
			-- SuperLive
			IF (EXISTS (SELECT 1 FROM @tblTransId WHERE Bettype BETWEEN 801 AND 899))
			BEGIN

				-- SuperLive on bettrans
				INSERT INTO @tblMsg (super, master, agent, player, mid, wld, adjTO, adjTO_Exposure, adjHTONoExtraPT
											,adjTO_RM, adjTO_Exposure_RM, adjHTONoExtraPT_RM, IsInsert, bettype, liveindicator)
					SELECT srecommend AS 'super', mrecommend AS 'master', recommend AS 'agent', custid AS 'player', matchid AS 'mid', winlostdate AS 'wld'
								   
						, - SUM(stake) AS 'adjTO'
								   
						, - SUM(ABS(stake)) AS 'adjTO_Exposure'
								   
						, - SUM((1-tpositiontaking)*ABS(stake)) AS 'adjHTONoExtraPT'
								   
						, CONVERT(MONEY, - SUM(stake*(CASE WHEN currency = 20 THEN 1 ELSE  actualrate END ))) AS 'adjTO_RM'
								   
						, CONVERT(MONEY, - SUM(ABS(-stake * (CASE WHEN currency = 20 THEN 1 ELSE  actualrate END )))) AS 'adjTO_Exposure_RM'
								   
						, CONVERT(MONEY, - SUM((1-tpositiontaking)*ABS(-stake)*(CASE WHEN currency = 20 THEN 1 ELSE  actualrate END ))) AS 'adjHTONoExtraPT_RM'
						, m.IsInsert AS 'IsInsert', b.bettype AS 'bettype', b.liveindicator AS 'liveindicator'
						FROM @tblTransId m
							INNER JOIN dbo.bettrans b WITH(NOLOCK) ON m.TransId = b.transid
						WHERE m.statusID BETWEEN 101 AND 103
							AND	1 = CASE WHEN srecommend IS NULL
										OR mrecommend IS NULL
										OR recommend IS NULL
										OR matchid IS NULL
										OR stake IS NULL
										OR tpositiontaking IS NULL
									THEN 0
								ELSE 1 END
							AND betfrom <> 'p'
							AND b.bettype BETWEEN 801 AND 899
						GROUP BY srecommend, mrecommend, recommend, custid, matchid, winlostdate, m.IsInsert, b.bettype,b.liveindicator

				-- SuperLive on translog
				INSERT INTO @tblMsg (super, master, agent, player, mid, wld, adjTO, adjTO_Exposure, adjHTONoExtraPT
						,adjTO_RM, adjTO_Exposure_RM, adjHTONoExtraPT_RM, IsInsert, bettype, liveindicator) 
					SELECT srecommend AS 'super', mrecommend AS 'master', recommend AS 'agent',custid AS 'player', eventID AS 'mid', winlostdate AS 'wld'
								   
							, SUM(stake) AS 'adjTO'
								   
							, SUM(ABS(stake)) AS 'adjTO_Exposure'
								   
							, SUM((1-tpositiontaking)*ABS(stake)) AS 'adjHTONoExtraPT'
								   
							, CONVERT(MONEY, SUM(stake*(CASE WHEN currency = 20 THEN 1 ELSE  actualrate END ))) AS 'adjTO_RM'
								   
							, CONVERT(MONEY, SUM(ABS(stake * (CASE WHEN currency = 20 THEN 1 ELSE  actualrate END )))) AS 'adjTO_Exposure_RM'
								   
							, CONVERT(MONEY, SUM((1-tpositiontaking)*ABS(stake)*(CASE WHEN currency = 20 THEN 1 ELSE  actualrate END ))) AS 'adjHTONoExtraPT_RM'
							, m.IsInsert AS 'IsInsert', gameID AS 'bettype', b.liveindicator
							FROM @tblTransId  m
								INNER JOIN dbo.translog b WITH(NOLOCK) ON m.TransId = b.translogid
							WHERE eventID > 0 AND m.statusID NOT BETWEEN 101 AND 103
			  					AND gameID BETWEEN 801 AND 899
								AND 1 = CASE WHEN srecommend IS NULL
												OR mrecommend IS NULL
												OR recommend IS NULL
												OR eventID IS NULL
												OR stake IS NULL
												OR tpositiontaking IS NULL
											THEN 0
										ELSE 1 END
								AND betfrom <> 'p'
							GROUP BY srecommend, mrecommend, recommend, custid, eventID, winlostdate, m.IsInsert, gameID, b.liveindicator

			END

			-- Sportbook without SuperLive
			INSERT INTO @tblMsg (super, master, agent, player, mid, wld, adjTO, adjTO_Exposure, adjHTONoExtraPT
						,adjTO_RM, adjTO_Exposure_RM, adjHTONoExtraPT_RM, IsInsert, bettype, liveindicator) 
				SELECT srecommend AS 'super', mrecommend AS 'master', recommend AS 'agent',custid AS 'player', matchid AS 'mid', winlostdate AS 'wld'
								   
					, SUM(b.stake) AS 'adjTO'
								   
					, SUM(t.stake) AS 'adjTO_Exposure'
								   
					, SUM((1-tpositiontaking)* t.stake) AS 'adjHTONoExtraPT'
								   
					, CONVERT(MONEY, SUM(b.stake*(CASE WHEN currency = 20 THEN 1 ELSE  actualrate END ))) AS 'adjTO_RM'
								   
					, CONVERT(MONEY, SUM(t.stake * (CASE WHEN currency = 20 THEN 1 ELSE  actualrate END ))) AS 'adjTO_Exposure_RM'
								   
					, CONVERT(MONEY, SUM((1-tpositiontaking) * t.stake * (CASE WHEN currency = 20 THEN 1 ELSE  actualrate END ))) AS 'adjHTONoExtraPT_RM'
					, m.IsInsert AS 'IsInsert', b.bettype AS 'bettype', b.liveindicator AS 'liveindicator'
				FROM @tblTransId m
					INNER JOIN dbo.bettrans b WITH(NOLOCK) ON m.TransId = b.transid
					CROSS APPLY (SELECT 
										CASE 
											WHEN b.betteam = 'h' AND b.bettype IN (1,3,7,8,20,21) 
													THEN (stake * CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END)
											WHEN b.betteam = 'a' AND b.bettype IN (1,3,7,8,20,21) 
													THEN - (stake *	CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END)							
											ELSE ABS(b.stake) -- normal
										END	
										AS stake																							
								) AS t
				WHERE matchid > 0 AND m.statusID NOT BETWEEN 101 AND 103
			  		--AND ((b.bettype < 31 and b.bettype NOT IN (9,29,10)) OR b.bettype between 121 and 999 OR b.bettype BETWEEN 1301 and 1399 OR b.bettype BETWEEN 9001 and 9399 OR b.bettype = 38)
					AND 1 = CASE WHEN srecommend IS NULL
									OR mrecommend IS NULL
									OR recommend IS NULL
									OR matchid IS NULL
									OR b.stake IS NULL
									OR tpositiontaking IS NULL
								THEN 0
							ELSE 1 END
					AND betfrom <> 'p'
				GROUP BY srecommend, mrecommend, recommend, custid, matchid, winlostdate, m.IsInsert, b.bettype, b.liveindicator


			SET @xml_TOControl = (	SELECT	super, master, agent, player, mid, wld, adjTO, adjTO_Exposure, adjHTONoExtraPT
											,adjTO_RM, adjTO_Exposure_RM, adjHTONoExtraPT_RM, IsInsert, bettype, liveindicator
									FROM @tblMsg					
									FOR XML PATH ('r'), ROOT)

		END

		ELSE
		BEGIN
			INSERT INTO @tblTransId(TransId, statusID, statusIDDeleted)
			SELECT msd.TransId, msd.statusID, msd.statusIDDeleted
			FROM @Messages m
				CROSS APPLY (SELECT x.v.value('(TransId/text())[1]','BIGINT') AS TransId,
									x.v.value('(StatusIDInserted/text())[1]','TINYINT') AS statusID,
									x.v.value('(StatusIDDeleted/text())[1]','TINYINT') AS statusIDDeleted
								FROM m.message_body.nodes('/r') AS x(v)
							) msd

			INSERT INTO @tblMsg (super, master, agent, player, mid, wld
						, adjTO, adjTO_Exposure, adjHTONoExtraPT
						, adjTO_RM, adjTO_Exposure_RM, adjHTONoExtraPT_RM, bettype, liveindicator)
			SELECT b.srecommend, b.mrecommend, b.recommend, 0 AS player, b.matchid, b.winlostdate, 
				SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -b.stake --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN b.stake --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN b.stake -- undo or calculate after refund
						 ELSE 0
					END) AS adj_TO,
			
				SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -tmp.stake --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN tmp.stake --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN tmp.stake -- undo or calculate after refund
						 ELSE 0
					END) AS adjTO_Exposure,
					
				SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -(1-b.tpositiontaking)*tmp.stake --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN (1-b.tpositiontaking)*tmp.stake --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN (1-b.tpositiontaking)*tmp.stake -- undo or calculate after refund
						 ELSE 0
					END) AS adj_HouseTO,
			
				SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -b.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN b.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN b.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) -- undo or calculate after refund
						 ELSE 0
					END) AS adj_TO_RM,
			
				SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -(tmp.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END)) --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN (tmp.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END)) --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN (tmp.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE b.actualrate END)) -- undo or calculate after refund
						 ELSE 0
					END) AS adjTO_Exposure_RM,
					
				SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -(1-b.tpositiontaking)*tmp.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN (1-b.tpositiontaking)*tmp.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN (1-b.tpositiontaking)*tmp.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) -- undo or calculate after refund
						 ELSE 0
					END) AS adj_HouseTO_RM
				, b.bettype AS 'bettype', b.liveindicator AS 'liveindicator'
			FROM @tblTransId t
				INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.transid = b.transid
				CROSS APPLY (SELECT 
									CASE 
										WHEN b.betteam in ('h') AND b.bettype IN (1,3,7,8,20,21) 
												THEN (stake * (CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END))
										WHEN b.betteam in ('a') AND b.bettype IN (1,3,7,8,20,21) 
												THEN - (stake *	(CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END))
										ELSE ABS(b.stake) -- normal
									END	
									AS stake																							
							) AS tmp
			GROUP BY b.srecommend, b.mrecommend, b.recommend, b.matchid, b.winlostdate, b.bettype, b.liveindicator
			HAVING SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -b.stake --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN b.stake --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN b.stake -- undo or calculate after refund
						 ELSE 0
						END) <> 0 --Only get changed stake
		
			UNION ALL
		
			SELECT b.srecommend, b.mrecommend, b.recommend, b.custid AS player, b.matchid, b.winlostdate, 
				SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -b.stake --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN b.stake --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN b.stake -- undo or calculate after refund
						 ELSE 0
					END) AS adj_TO,
			
				SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -tmp.stake --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN tmp.stake --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN tmp.stake -- undo or calculate after refund
						 ELSE 0
					END) AS adjTO_Exposure,
					
				SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -(1-b.tpositiontaking)*tmp.stake --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN (1-b.tpositiontaking)*tmp.stake --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN (1-b.tpositiontaking)*tmp.stake -- undo or calculate after refund
						 ELSE 0
					END) AS adj_HouseTO,
			
				SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -b.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END)  --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN b.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN b.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) -- undo or calculate after refund
						 ELSE 0
					END) AS adj_TO_RM,
			
				SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -tmp.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN tmp.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN tmp.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) -- undo or calculate after refund
						 ELSE 0
					END) AS adjTO_Exposure_RM,
					
				SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -(1-b.tpositiontaking)*tmp.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN (1-b.tpositiontaking)*tmp.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN (1-b.tpositiontaking)*tmp.stake * (CASE WHEN b.currency = 20 THEN 1 ELSE  b.actualrate END) -- undo or calculate after refund
						 ELSE 0
					END) AS adj_HouseTO_RM
					, b.bettype AS 'bettype', b.liveindicator AS 'liveindicator'
			FROM @tblTransId t 
				INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.transid = b.transid
				CROSS APPLY (SELECT 
									CASE 
										WHEN b.betteam ='h' AND b.bettype IN (1,3,7,8,20,21) 
												THEN (stake * (CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END))
										WHEN b.betteam ='a' AND b.bettype IN (1,3,7,8,20,21) 
												THEN - (stake *	(CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END))
										ELSE ABS(b.stake) -- normal
									END	
									AS stake																							
							) AS tmp
							
			WHERE EXISTS (SELECT 1 FROM bodb02.dbo.custAccount ca WITH (NOLOCK) WHERE ca.CustID = b.custid)
			GROUP BY b.srecommend, b.mrecommend, b.recommend, b.custid, b.matchid, b.winlostdate, b.bettype, b.liveindicator
			HAVING SUM(CASE WHEN t.statusid IN (101,102,103) AND t.statusIDDeleted IN (0,1,111,112,113) THEN -b.stake --delete ticket
						 WHEN t.statusid = 0 AND t.statusIDDeleted = 102 THEN b.stake --recover ticket
						 WHEN t.statusIDDeleted  = 103 AND t.statusid IN (0,111,112,113) THEN b.stake -- undo or calculate after refund
						 ELSE 0
						END) <> 0 --Only get changed stake
					
		
			SET @xml_TOControl = (
				SELECT super, master, agent, player, mid, wld, adjTO, adjTO_Exposure, adjHTONoExtraPT
					, adjTO_RM, adjTO_Exposure_RM, adjHTONoExtraPT_RM, 0 AS IsInsert, bettype, liveindicator
				FROM @tblMsg					
				FOR XML PATH ('r'), ROOT)
		
		END

		IF @xml_TOControl IS NOT NULL 
		BEGIN
			--TRY
			EXEC sb.TOControl_TransitionIns @XMLString = @xml_TOControl
			--CATCH
		END

	END
END

GO
GO