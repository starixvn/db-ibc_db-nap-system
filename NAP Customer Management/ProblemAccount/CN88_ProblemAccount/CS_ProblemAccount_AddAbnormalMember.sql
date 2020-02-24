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
							
	DECLARE @tmpCustInsert TABLE (custid INT)
	
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
			INTO @tmpCustInsert
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
				
		END
		*/
		UPDATE s
		SET s.VValue = CAST(@MaxID AS VARCHAR(10))
		FROM DBACC.bodb02.dbo.SystemSettings s WITH (ROWLOCK) 
		WHERE VName = 'ProblemAccount_MaxId'
	END
END
