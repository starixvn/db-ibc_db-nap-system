/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Misc_OpenCloseMembers_List] 
	@username VARCHAR(30),
	@TotalItems INT = 0 OUTPUT,
	@ItemPerPage INT = 50,
	@PageIndex INT = 1,
	@IsClosed INT = -1,
	@ErrorCode INT = NULL OUTPUT,
	@ErrorMsg VARCHAR(max) = '' OUTPUT,
	@Language VARCHAR(2)= 'E'
AS
/*
	Created: 2014-03-13
	Author: Dom
	Task : get list of accounts to close/open
	DB: DBAGE/bodb02

	Revisions:
		- 20190514@Paul: Create new SP [RedmineID: #113198]
		- 20190527@Elodie: New account status for CN88 [Redmine: 113198]
		- 20210505@Tina: Lock account & indirect close account [redmine: #148600]
		- 20220110@Eden: Saba Casino use DCS Setting [RedmineID: #164280]
	
	Example: NAP_customerUpdClosebyList_sel
				@username = 'SSS',
				@TotalPages = 0 ,
				@ItemPerPage = 20,
				@PageIndex = 1
*/
BEGIN
	DECLARE @custid INT = NULL, @roleid	INT = NULL
	--DECLARE @closedacc TABLE(custid INT)
	CREATE TABLE #Customer (custid INT,srecommend INT,mrecommend INT,recommend INT,username VARCHAR(50))

	SELECT @custid = ci.custid, @roleid = ci.roleid 
	FROM custinfo ci WITH (NOLOCK) 
		INNER JOIN dbo.Customer c WITH (NOLOCK) ON c.custid = ci.custid
		INNER JOIN CustProductStatus cps WITH (NOLOCK) ON cps.CustID = c.custid
	WHERE ci.username = @username 
		AND ci.roleid <> 1
		AND CloseInfo = 0
		AND c.site <> 'CN88'

	IF(@custid IS NULL)
	BEGIN				
		SELECT @ErrorMsg = [dbo].[f_Get_MsgNamebyMsgID](40001,@Language), @ErrorCode = 201
		RETURN
	END

	---------------INSERT TEMP CUSTOMER------------------------
	IF(@roleid=4)
	BEGIN
		--INSERT INTO @closedacc
		--SELECT ci.custid 
		--FROM custInfo ci WITH (NOLOCK) 
		--	INNER JOIN CustProductStatus cps WITH (NOLOCK) ON cps.CustID = ci.custid
		--WHERE srecommend = @custid AND (roleid IN(2,3)) AND cps.CloseInfo > 0

		INSERT INTO #Customer
		SELECT ci.custid,srecommend,mrecommend,recommend,username 
		FROM custinfo ci (NOLOCK)
			CROSS APPLY  (SELECT CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS closed
							, CloseInfo
						  FROM dbo.CustProductStatus  WITH(NOLOCK)
						  WHERE CustID = ci.custid
						) AS cps
			CROSS APPLY (SELECT * FROM f_GetInfoStatus(cps.CloseInfo)) AS cl
		WHERE (srecommend = @custid)
				AND roleid=1
				AND (@IsClosed = -1 or cps.closed = @IsClosed)
				AND cl.SuperStatus + cl.MasterStatus + cl.AgentStatus = 0
	END
	ELSE IF(@roleid=3)
	BEGIN
		--INSERT INTO @closedacc
		--SELECT ci.custid 
		--FROM custInfo ci WITH (NOLOCK) 
		--	INNER JOIN CustProductStatus cps WITH (NOLOCK) ON cps.CustID = ci.custid
		--WHERE mrecommend = @custid AND roleid=2 AND cps.CloseInfo > 0

		INSERT INTO #Customer
		SELECT ci.custid,srecommend,mrecommend,recommend,username 
		FROM custinfo ci WITH (NOLOCK)
			CROSS APPLY  (SELECT CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS closed
							, CloseInfo
						  FROM dbo.CustProductStatus  WITH(NOLOCK)
						  WHERE CustID = ci.custid
						) AS cps
			CROSS APPLY (SELECT * FROM f_GetInfoStatus(cps.CloseInfo)) AS cl
		WHERE (mrecommend = @custid)
				AND roleid=1
				AND (@IsClosed = -1 or cps.closed = @IsClosed)
				AND cl.SuperStatus + cl.MasterStatus + cl.AgentStatus = 0
	END
	ELSE IF(@roleid=2)
	BEGIN
		INSERT INTO #Customer
		SELECT ci.custid,srecommend,mrecommend,recommend,username 
		FROM custinfo ci WITH (NOLOCK)
			CROSS APPLY  (SELECT CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS closed
									FROM dbo.CustProductStatus  WITH(NOLOCK)
									WHERE CustID = ci.custid
								) AS cps
		WHERE (recommend = @custid)
				AND roleid=1
				AND (@IsClosed = -1 or cps.closed = @IsClosed)
	END
	---------------END INSERT TEMP CUSTOMER------------------------

	DELETE #Customer 
	WHERE srecommend IN (SELECT custid FROM dep_custsuper(NOLOCK))
			--OR mrecommend IN(SELECT custid FROM @closedacc)
			--OR recommend IN(SELECT custid FROM @closedacc)
		
	SELECT ROW_NUMBER() OVER (ORDER BY c.username) as row, c.custid 
	INTO #CustomerList
	FROM #Customer c

	SELECT custid, row 
	INTO #temp
	FROM #CustomerList 
	WHERE row BETWEEN @ItemPerPage*@PageIndex - @itemperpage+1 AND @ItemPerPage*@PageIndex

	SELECT @TotalItems = COUNT(1) FROM #CustomerList 

	IF @roleid = 4
	BEGIN
		SELECT ci.custid,
				master.username master,
				agent.username agent,
				ci.username member, 
				CASE WHEN cps.CloseInfo > 0 THEN 1 ELSE 0 END closed
		FROM custInfo(NOLOCK) ci
			INNER JOIN custInfo(NOLOCK) master ON master.custid = ci.mrecommend
			INNER JOIN custInfo(NOLOCK) agent ON agent.custid = ci.recommend
			INNER JOIN CustProductStatus cps WITH (NOLOCK) ON cps.CustID = ci.custid
		WHERE ci.custid IN(SELECT custid FROM #temp)
		ORDER BY master.username ASC, 
				agent.username ASC,
				ci.username ASC,
				ci.closed ASC
	END
	ELSE IF @roleid = 3
	BEGIN
		SELECT ci.custid,
				agent.username agent,
				ci.username member, 
				CASE WHEN cps.CloseInfo > 0 THEN 1 ELSE 0 END closed
		FROM custInfo(NOLOCK) ci
			INNER JOIN custInfo(NOLOCK) agent ON agent.custid = ci.recommend
			INNER JOIN CustProductStatus cps WITH (NOLOCK) ON cps.CustID = ci.custid
		WHERE ci.custid IN(SELECT custid FROM #temp)
		ORDER BY agent.username,
				ci.username,
				ci.closed
	END
	ELSE IF @roleid = 2
	BEGIN
		SELECT ci.custid,
				ci.username member, 
		
				CASE WHEN cps.CloseInfo > 0 THEN 1 ELSE 0 END closed
		FROM custInfo(NOLOCK) ci
			INNER JOIN CustProductStatus cps WITH (NOLOCK) ON cps.CustID = ci.custid
		WHERE ci.custid IN(SELECT custid FROM #temp)
		ORDER BY ci.username,
				ci.closed
	END

	DROP TABLE #Customer
	DROP TABLE #CustomerList
	DROP TABLE #temp
END
