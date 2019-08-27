/*<info serverAlias="DBCUST-CustDB" executers="" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE CS_ProblemAccount_AddAbnormalMember	
AS
/*
	Created: Elodie
	Date: 20190808
	Task : Add abnormal member
	DB: DBCUST/CustDB

	Revisions:
		- 20190808@Elodie: Initial SP [Redmine:#116814]

	Parameter's explaination: 
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @MinId INT, @MaxId INT
	CREATE TABLE #tmpCust (CustId INT)

	SELECT @MinId = CAST(VValue AS INT) FROM DBACC.bodb02.dbo.SystemSettings WITH (NOLOCK) WHERE VName = 'ProblemAccount_MaxId'

	SELECT @MaxId = MAX(Id) FROM DBACC.bodb02.dbo.TicketVoiding_VoidedTransaction WITH (NOLOCK)

	IF @MaxId > @MinId
	BEGIN
		INSERT INTO #tmpCust (CustId)
		SELECT c.CustId
		FROM DBACC.bodb02.dbo.TicketVoiding_VoidedTransaction v WITH (NOLOCK)
			INNER JOIN Customer c WITH (NOLOCK) ON c.custid = v.CustID
		WHERE v.Id > @MinId AND v.Id <= @MaxId
			AND c.site = 'CN88'

		UPDATE pa 
		SET pa.ProblemStatus = ProblemStatus | 1,
			pa.IsAbnormalMember = 1
		FROM dbo.CS_ProblemAccount pa WITH (ROWLOCK)
			INNER JOIN #tmpCust t ON t.CustId = pa.CustId

		INSERT INTO dbo.CS_ProblemAccount (CustId, ProblemStatus, ReasonId, Comment, MaxBet, MaxPerEvent, CreatedDate, IsReviewed, IsAbnormalMember)
		SELECT CustId, 1, NULL, NULL, NULL, NULL, GETDATE(), 0, 1
		FROM #tmpCust t
		WHERE NOT EXISTS (SELECT 1 FROM CS_ProblemAccount WHERE CustId = t.CustId)

		UPDATE s
		SET s.VValue = CAST(@MaxID AS VARCHAR(10))
		FROM DBACC.bodb02.dbo.SystemSettings s WITH (ROWLOCK) 
		WHERE VName = 'ProblemAccount_MaxId'
	END
END
GO
