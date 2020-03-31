/*<info serverAlias="DBCUST-CustDB" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[CS_ProblemAccount_AddAbnormalMember]
AS
/*
	Created: Elodie
	Date: 20190808
	Task : Add abnormal member
	DB: DBCUST/CustDB

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]
		- 20190930@Elodie: Only add the member that is voided ticket abnormal into CS_ProblemAccount [Redmine:#121104]
		- 20200121@Johnson: Add deposit & credit customer [redine:#128077]
		- 20200327@Johnson: Wrongly convert exchange rate of Reduce Bet Limit [redmine:#131318]
	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@startRun DATETIME, @duration INT
	DECLARE @MinId INT, 
			@MaxId INT,			
			@LogData VARCHAR(500),
			@MaxBet MONEY,
			@MaxPerEvent MONEY,
			@ReasonName VARCHAR(100),
			@custid INT,
			@username VARCHAR(30)			
		
	CREATE TABLE #tmpCustVoidTicket(custid INT,transid BIGINT, matchid INT, reasonid TINYINT)
	CREATE TABLE #tmpCust (CustId INT, 
							username VARCHAR(30), 
							currency INT, 
							site VARCHAR(10), 
							srecommend INT, 
							isDeposit BIT DEFAULT 0, 
							isVip BIT DEFAULT 0, 
							ActionID TINYINT,
							ReasonId TINYINT, 
							ReasonName VARCHAR(100), 
							IsAcknowledgement BIT, 
							MaxBet MONEY, 
							MaxPerEvent MONEY, 
							isLogNew BIT DEFAULT 0, 
							isLogVip BIT DEFAULT 0)
							
	DECLARE @tmpCustInsert TABLE (custid INT, MaxBet MONEY, MaxPerEvent MONEY)
	
	SELECT @startRun = GETDATE()
	SELECT @MinId = CAST(VValue AS INT) FROM DBACC.bodb02.dbo.SystemSettings WITH (NOLOCK) WHERE VName = 'ProblemAccount_MaxId'

	SELECT @MaxId = MAX(Id) FROM DBACC.bodb02.dbo.TicketVoiding_VoidedTransaction WITH (NOLOCK)

	IF @MaxId > @MinId
	BEGIN
		SELECT @MaxId = CASE WHEN @MaxId - @MinId > 5000 THEN @MinId + 5000 ELSE @MaxId END
		
		INSERT INTO #tmpCustVoidTicket(custid,transid,matchid,reasonID)
		SELECT custid, transid,matchid,SubIssueTypeID
		FROM DBACC.bodb02.dbo.TicketVoiding_VoidedTransaction v WITH (NOLOCK)
		WHERE v.Id > @MinId AND v.Id <= @MaxId AND v.IssueTypeID = 11
		
		INSERT INTO #tmpCust (CustId,username,currency,site,srecommend,reasonID,ActionID)
		SELECT DISTINCT c.CustId,c.username,c.currency,ISNULL(c.site,''),c.srecommend,v.reasonID,1--Default None
		FROM #tmpCustVoidTicket v
			INNER JOIN Customer c WITH (NOLOCK) ON c.custid = v.CustID
			
				
		UPDATE t
		SET isDeposit = 1,
			t.site = s.site
		FROM #tmpCust t
			INNER JOIN Dep_CustSuper s WITH(NOLOCK) ON t.srecommend = s.custid
		
		UPDATE t
		SET t.ReasonName = p.ReasonName
		FROM #tmpCust t 
			INNER JOIN ProblemAccountReason p WITH(NOLOCK) ON t.ReasonID = p.ReasonID
			
		--processing for CN88
		IF EXISTS(SELECT 1 FROM #tmpCust WHERE site = 'CN88')
		BEGIN
			UPDATE pa 
			SET pa.ProblemStatus = ProblemStatus | 1,
				pa.IsAbnormalMember = 1
			FROM dbo.CS_ProblemAccount pa WITH (ROWLOCK)
				INNER JOIN #tmpCust t ON t.CustId = pa.CustId
			WHERE site = 'CN88'
			
			INSERT INTO dbo.CS_ProblemAccount (CustId, ProblemStatus, ReasonId, Comment, MaxBet, MaxPerEvent, CreatedDate, IsReviewed, IsAbnormalMember)			
			OUTPUT INSERTED.custid 
			INTO @tmpCustInsert(custid)
			SELECT CustId, 1, NULL, NULL, NULL, NULL, GETDATE(), 0, 1			
			FROM #tmpCust t
			WHERE NOT EXISTS (SELECT 1 FROM CS_ProblemAccount WHERE CustId = t.CustId)
				AND site = 'CN88'
				
			--Logging 
			SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
			
			--log for new problem accounts
			WHILE(1=1)
			BEGIN
				UPDATE TOP (1) t1
				SET @username = username,
					@custid = t1.custid,
					@ReasonName = ISNULL(t1.ReasonName,''),
					isLogNew = 1
				FROM #tmpCust t1
					INNER JOIN @tmpCustInsert t2 ON t1.custid = t2.custid
				WHERE isLogNew = 0
				
				IF @@ROWCOUNT =0
					BREAK;
					
				SELECT  @LogData = '<R'
								+ ' Username="' + @UserName + '"'								
								+ ' Reason="'+@ReasonName+'"'
								+ ' />'
									
				EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
					@UserId				=  862400,--Starix2
					@CustId				= @CustId,
					@ActionId			= 31632,
					@TrackingValue		= @LogData,					
					@Duration			= @Duration
			END							
		END
		
		----processing for Credit
		IF EXISTS(SELECT 1 FROM #tmpCust WHERE site <> 'CN88' AND isDeposit <> 1)
		BEGIN
			DELETE @tmpCustInsert
						
			UPDATE pa 
			SET pa.ProblemStatus = ProblemStatus | 1,
				pa.IsAbnormalMember = 1
			FROM dbo.ProblemAccount pa WITH (ROWLOCK)
				INNER JOIN #tmpCust t ON t.CustId = pa.CustId
			WHERE site <> 'CN88'
				AND isDeposit <> 1
				
			INSERT INTO dbo.ProblemAccount (CustId, ProblemStatus, ReasonId, ActionID, Comment, MaxBet, MaxPerEvent, CreatedDate, IsReviewed, IsAbnormalMember)			
			OUTPUT INSERTED.custid 
			INTO @tmpCustInsert(custid)
			SELECT CustId, 1, NULL, ActionID, NULL, NULL, NULL, GETDATE(), 0, 1			
			FROM #tmpCust t
			WHERE NOT EXISTS (SELECT 1 FROM ProblemAccount WHERE CustId = t.CustId)
				AND site <> 'CN88'
				AND isDeposit <> 1
				
			--Logging 
			SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
			
			--log for new problem accounts
			WHILE(1=1)
			BEGIN
				UPDATE TOP (1) t1
				SET @username = username,
					@custid = t1.custid,
					@ReasonName = ISNULL(t1.ReasonName,''),					
					isLogNew = 1
				FROM #tmpCust t1
					INNER JOIN @tmpCustInsert t2 ON t1.custid = t2.custid
				WHERE isLogNew = 0
				
				IF @@ROWCOUNT =0
					BREAK;
					
				SELECT  @LogData = '<R'
								+ ' Username="' + @UserName + '"'								
								+ ' Reason="' + @ReasonName + '"'
								+ ' />'
									
				EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
					@UserId				=  862400,--Starix2
					@CustId				= @CustId,
					@ActionId			= 31632,
					@TrackingValue		= @LogData,					
					@Duration			= @Duration
			END							
		END
		
		----processing for Deposit
		IF EXISTS(SELECT 1 FROM #tmpCust WHERE isDeposit = 1)
		BEGIN
			DECLARE @tmpCustVip TABLE (custid INT)			
			DECLARE @tmpMatchUpdate TABLE(custid INT, matchid1 INT, matchid2 INT)
			DECLARE @today DATE
			SELECT @today = GETDATE()
			
			DELETE @tmpCustInsert
			
			UPDATE t
			SET t.matchid = b.matchid
			FROM #tmpCustVoidTicket t
				INNER JOIN DBACC.bodb02.dbo.bettrans b WITH(NOLOCK) ON t.transid = b.transid
			WHERE t.matchid = 0
				AND t.custid IN (SELECT custid FROM #tmpCust WHERE isDeposit = 1)
						
			UPDATE t
			SET MaxBet = CASE WHEN t.currency = 20 THEN 100 ELSE ISNULL(ROUND(100/NULLIF(ISNULL(CNY,0),0),0),0) END,
				MaxPerEvent = CASE WHEN t.currency = 20 THEN 300 ELSE ISNULL(ROUND(300/NULLIF(ISNULL(CNY,0),0),0),0) END
			FROM #tmpCust t
				INNER JOIN ExchangeDailyOanda e WITH(NOLOCK) ON t.currency = e.ExchangeId
			WHERE ExchangeDate = @today
				AND isDeposit = 1
			
			UPDATE t
			SET t.isVip = CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END,
				t.IsAcknowledgement = ISNULL(l.IsAcknowledgement,0)
			FROM #tmpCust t
				LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON t.custid = d.custid
				LEFT JOIN bodb_Licensee.dbo.Licensees l WITH(NOLOCK) ON t.site = l.LicenseeName
			WHERE t.isDeposit = 1	
			
			;WITH t AS(
						SELECT  custid, matchid, ROW_NUMBER() OVER(PARTITION BY custid ORDER BY matchid ASC) rn
						FROM (SELECT DISTINCT custid,matchid 
							FROM #tmpCustVoidTicket cv
							WHERE custid IN (SELECT custid FROM #tmpCust WHERE isDeposit = 1)								
								AND NOT EXISTS(SELECT 1 FROM ProblemAccount p1 WITH(NOLOCK) WHERE cv.custid = p1.custid AND cv.matchid = p1.matchid1)
								AND NOT EXISTS(SELECT 1 FROM ProblemAccount p2 WITH(NOLOCK) WHERE cv.custid = p2.custid AND cv.matchid = p2.matchid2)
							)tmp
					)
			SELECT * 
			INTO #tmpCustMatch	
			FROM t			
			WHERE rn <= 2
			ORDER BY custid
			
			--insert new problem account
			INSERT INTO dbo.ProblemAccount (CustId, ProblemStatus, ReasonId, ActionID, Comment, MaxBet, MaxPerEvent, CreatedDate, IsReviewed, IsAbnormalMember)
			OUTPUT INSERTED.custid, INSERTED.MaxBet, INSERTED.MaxPerEvent 
			INTO @tmpCustInsert(custid,MaxBet,MaxPerEvent)
			SELECT t.CustId, 0, NULL, ActionID, NULL,CASE WHEN isVip = 0 AND IsAcknowledgement = 1 THEN MaxBet ELSE NULL END, 
				CASE WHEN isVip = 0 AND IsAcknowledgement = 1 THEN MaxPerEvent ELSE NULL END, GETDATE(), 0, 1			
			FROM #tmpCust t
			WHERE NOT EXISTS (SELECT 1 FROM ProblemAccount WHERE CustId = t.CustId)
				AND isDeposit = 1
				
			--update match void of problem account
			UPDATE p 
			SET p.matchid1 = CASE WHEN p.matchid1 IS NULL THEN t1.matchid ELSE p.matchid1 END,
				p.matchid2 = CASE WHEN p.matchid1 IS NOT NULL AND p.matchid2 IS NULL THEN t1.matchid 
									WHEN p.matchid1 IS NULL AND p.matchid2 IS NULL AND t2.matchid IS NOT NULL THEN t1.matchid 
									ELSE p.matchid2 END,
				p.IsAbnormalMember = CASE WHEN p.IsAbnormalMember = 0 THEN 1 ELSE p.IsAbnormalMember END
			OUTPUT INSERTED.custid, INSERTED.matchid1, INSERTED.matchid2
			INTO @tmpMatchUpdate(custid,matchid1,matchid2)
			FROM ProblemAccount p WITH(UPDLOCK,ROWLOCK)
				INNER JOIN #tmpCustMatch t1 ON p.custid = t1.custid AND t1.rn = 1
				LEFT JOIN #tmpCustMatch t2 ON p.custid = t2.custid AND t2.rn = 2
			WHERE p.matchid1 IS NULL OR p.matchid2 IS NULL	
			
			--set isMarkVoid = 1 for account has 2 matches voided
			UPDATE p
			SET p.isMarkVoid = 1
			FROM ProblemAccount p
				INNER JOIN @tmpMatchUpdate rs ON p.custid = rs.custid
			WHERE rs.matchid1 IS NOT NULL AND rs.matchid2 IS NOT NULL
			
			--un-set VIP if has 2 matches are voided include new problem accounts & existing
			IF EXISTS (SELECT 1 FROM @tmpMatchUpdate WHERE matchid1 IS NOT NULL AND matchid2 IS NOT NULL)
				OR EXISTS (SELECT 1 FROM #tmpCustMatch WHERE rn =2)
			BEGIN
				DELETE Dep_CustVIP
				OUTPUT DELETED.custid
				INTO @tmpCustVip
				WHERE custid IN (
					SELECT custid FROM @tmpMatchUpdate WHERE matchid1 IS NOT NULL AND matchid2 IS NOT NULL
					UNION SELECT custid FROM #tmpCustMatch WHERE rn =2
				)
				
				--reduce betlimit for account has 2 matches voided
				UPDATE p
				SET p.MaxBet = t.MaxBet,
					p.MaxPerEvent = t.MaxPerEvent
				FROM ProblemAccount p WITH(UPDLOCK,ROWLOCK)
					INNER JOIN #tmpCust t ON p.custid = t.custid
				WHERE p.custid IN (SELECT custid FROM @tmpCustVip)				
			END	

			--Logging 
			SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
			
			--log for new problem accounts
			WHILE(1=1)
			BEGIN
				UPDATE TOP (1) t1
				SET @username = username,
					@custid = t1.custid,
					@MaxBet = t2.MaxBet,
					@MaxPerEvent = t2.MaxPerEvent,
					@ReasonName = ISNULL(t1.ReasonName,''),
					isLogNew = 1
				FROM #tmpCust t1
					INNER JOIN @tmpCustInsert t2 ON t1.custid = t2.custid
				WHERE isLogNew = 0
				
				IF @@ROWCOUNT =0
					BREAK;
					
				SELECT  @LogData = '<R'
								+ ' Username="' + @UserName + '"'								
								+ ' MPM="' + COALESCE(dbo.f_FomatNumber (CAST (@MaxPerEvent AS VARCHAR(50))), SPACE(1)) + '"'
								+ ' Max="' + COALESCE(dbo.f_FomatNumber (CAST (@MaxBet AS VARCHAR(50))), SPACE(1)) + '"'
								+ ' Reason="'+ @ReasonName + '"'							
								+ ' />'
									
				EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
					@UserId				=  862400,--Starix2
					@CustId				= @CustId,
					@ActionId			= 31632,
					@TrackingValue		= @LogData,					
					@Duration			= @Duration
			END	

			--log for un-set VIP status
			WHILE(1=1)
			BEGIN
				UPDATE TOP (1) t1
				SET @username = username,
					@custid = t1.custid,
					@MaxBet = MaxBet,
					@MaxPerEvent = MaxPerEvent,
					isLogVip = 1
				FROM #tmpCust t1
					INNER JOIN @tmpCustVip t2 ON t1.custid = t2.custid
				WHERE isLogVip = 0
				
				IF @@ROWCOUNT =0
					BREAK;
					
				SELECT  @LogData = '<R'
								+ ' Username="' + @UserName + '"'
								+ ' MPM="' + COALESCE(dbo.f_FomatNumber (CAST (@MaxPerEvent AS VARCHAR(50))), SPACE(1)) + '"'
								+ ' Max="' + COALESCE(dbo.f_FomatNumber (CAST (@MaxBet AS VARCHAR(50))), SPACE(1)) + '"'
								+ ' />'
									
				EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
					@UserId				=  862400,--Starix2
					@CustId				= @CustId,
					@ActionId			= 31633,
					@TrackingValue		= @LogData,					
					@Duration			= @Duration
			END	
		END
		
		UPDATE s
		SET s.VValue = CAST(@MaxID AS VARCHAR(10))
		FROM DBACC.bodb02.dbo.SystemSettings s WITH (ROWLOCK) 
		WHERE VName = 'ProblemAccount_MaxId'
	END
END


