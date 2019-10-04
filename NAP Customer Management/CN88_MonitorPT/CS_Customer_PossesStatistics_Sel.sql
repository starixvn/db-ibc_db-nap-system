/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[CS_Customer_PossessStatistics_Sel]	
	@SB_from TINYINT = 0,
	@SB_to TINYINT = 0,	
	@NS_from TINYINT = 0,
	@NS_to TINYINT = 0,
	@username VARCHAR(30) = NULL,
	@AgentStatus VARCHAR(100) = '',
	@DangerLevel TINYINT,
	@MonitorPT TINYINT = 2,
	@SortBy TINYINT,
	@FilterPossess VARCHAR(10) = '',
	@FilterDanger VARCHAR(10) = '',
	@pageIndex	INT = 1,
	@pageSize	INT = 50,
	@totalItems INT = 0 OUTPUT	
AS
/*
	Created: 20190926@Johnson
	Task: CN88 monitor SMA PT
	DB: DBCUST/CUSTDB
	Original:

	Revisions:	
		- 20190930@Johnson: initial sp [redmine:#117714]
	
	Parameter's Explanation:
		-@AgentStatus= 1:inactive, 2: suspended, 3:view only, 4:active  
		-@MonitorPT= 0: NO , 1: yes, 2: all
		-@SortBy= 1: SB% (A-Z), 2: SB% (Z-A), 3: NS% (A-Z), 4: NS% (Z-A), 5:SMA (A-Z), 6:SMA (Z-A)
		-@FilterPossess =: 'AND', 'OR'
		-@FilterDanger=: '>=', '=<', '='
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @sql NVARCHAR(MAX),
			@custid INT,
			@roleid TINYINT,
			@IsEditablePT BIT,
			@RowCount INT, 
			@RowStart INT, 
			@RowEnd INT
	
	IF @MonitorPT = 2 SET @MonitorPT = NULL
	
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 
			
	SELECT @IsEditablePT = IsEditablePT FROM f_CS_GetEditablePTDate(1)
	
	CREATE TABLE #AgentList (custid INT,
							username VARCHAR(50),
							srecommend INT,
							mrecommend INT,
							isMonitorPT BIT, 
							Danger TINYINT, 
							Status TINYINT, 
							SuperPT_SB TINYINT, 
							MasterPT_SB TINYINT,
							AgentPT_SB TINYINT,
							SuperPT_NS TINYINT,
							MasterPT_NS TINYINT,
							AgentPT_NS TINYINT)
	
	IF @username IS NULL
	BEGIN
		INSERT INTO #AgentList(custid, username, srecommend, mrecommend, isMonitorPT)
		SELECT c.custid, username, srecommend, mrecommend, ISNULL(isMonitorPT,0)		
		FROM customer c WITH(NOLOCK)
			CROSS APPLY(select top (1) ca.isMonitorPT 
						FROM custAgent ca WITH(NOLOCK) 
						where ca.custid = c.custid 
							AND ISNULL(ca.isMonitorPT,0) = ISNULL(@MonitorPT,ISNULL(ca.isMonitorPT,0))
				)t
		WHERE c.roleid = 2
			AND c.site = 'CN88'
	END
	ELSE 
	BEGIN
		SELECT @custid = custid, @roleid = roleid 
		FROM customer WITH(NOLOCK) 
		WHERE username = @username
			AND site = 'CN88'		
		
		IF @roleid = 4
		BEGIN
			INSERT INTO #AgentList(custid, username, srecommend, mrecommend, isMonitorPT)
			SELECT c.custid, username, srecommend, mrecommend, ISNULL(isMonitorPT,0)		
			FROM customer c WITH(NOLOCK)
				CROSS APPLY(select top (1) ca.isMonitorPT 
							FROM custAgent ca WITH(NOLOCK) 
							where ca.custid = c.custid 
								AND ISNULL(ca.isMonitorPT,0) = ISNULL(@MonitorPT,ISNULL(ca.isMonitorPT,0))
					)t
			WHERE c.roleid = 2
				AND srecommend = @custid
		END	
		ELSE IF @roleid = 3
		BEGIN
			INSERT INTO #AgentList(custid, username, srecommend, mrecommend, isMonitorPT)
			SELECT c.custid, username, srecommend, mrecommend, ISNULL(isMonitorPT,0)		
			FROM customer c WITH(NOLOCK)
				CROSS APPLY(select top (1) ca.isMonitorPT 
							FROM custAgent ca WITH(NOLOCK) 
							where ca.custid = c.custid 
								AND ISNULL(ca.isMonitorPT,0) = ISNULL(@MonitorPT,ISNULL(ca.isMonitorPT,0))
					)t
			WHERE c.roleid = 2
				AND mrecommend = @custid
		END
		ELSE IF @roleid = 2
		BEGIN
			INSERT INTO #AgentList(custid, username, srecommend, mrecommend, isMonitorPT)
			SELECT c.custid, username, srecommend, mrecommend, ISNULL(isMonitorPT,0)		
			FROM customer c WITH(NOLOCK)
				CROSS APPLY(select top (1) ca.isMonitorPT 
							FROM custAgent ca WITH(NOLOCK) 
							where ca.custid = c.custid 
								AND ISNULL(ca.isMonitorPT,0) = ISNULL(@MonitorPT,ISNULL(ca.isMonitorPT,0))
					)t
			WHERE c.custid = @custid
		END
			
	END
	
	SELECT @sql = 'UPDATE ag
	SET ag.Danger = ci.Danger2,
		ag.status = s.CustStatus
	FROM #AgentList ag
		INNER JOIN custinfo ci WITH(NOLOCK) ON ag.custid = ci.custid AND ci.Danger2 ' + @FilterDanger + CAST(@DangerLevel AS VARCHAR(10)) +'
		CROSS APPLY (SELECT TOP 1 CustStatus FROM dbo.f_CS_GetCustomerStatus(ag.custid)) s 
	WHERE s.CustStatus IN (' + @AgentStatus + ')' 
	
	EXEC sp_executesql @sql
	
	DELETE #AgentList WHERE Danger IS NULL OR status IS NULL
	
	;WITH t as (		
	SELECT ag.custid,
		MAX(CASE WHEN cs.sporttype = 1 AND bettype = 1 THEN SuperPT ELSE 0 END ) as SuperPT_SB,
		MAX(CASE WHEN cs.sporttype = 1 AND bettype = 1 THEN MasterPT ELSE 0 END ) as MasterPT_SB,
		MAX(CASE WHEN cs.sporttype = 1 AND bettype = 1 THEN AgentPT ELSE 0 END ) AgentPT_SB,
		MAX(CASE WHEN cs.sporttype = 9998 AND bettype = 81 THEN SuperPT ELSE 0 END ) SuperPT_NS,
		MAX(CASE WHEN cs.sporttype = 9998 AND bettype = 81 THEN MasterPT ELSE 0 END ) MasterPT_NS,
		MAX(CASE WHEN cs.sporttype = 9998 AND bettype = 81 THEN AgentPT ELSE 0 END ) AgentPT_NS
	FROM #AgentList ag
		CROSS APPLY(SELECT sporttype, bettype, 
						CASE WHEN @IsEditablePT = 1 THEN SuperPT2 ELSE SuperPT END as SuperPT, 
						CASE WHEN @IsEditablePT = 1 THEN MasterPT2 ELSE MasterPT END as MasterPT, 
						CASE WHEN @IsEditablePT = 1 THEN AgentPT2 ELSE AgentPT END as AgentPT
					FROM dbo.f_CS_GetPTGroup_Member(ag.custid)
		) cs
	GROUP BY ag.custid	
	) 
	UPDATE l
	SET SuperPT_SB = t.SuperPT_SB,
		MasterPT_SB = t.MasterPT_SB,
		AgentPT_SB = t.AgentPT_SB,
		SuperPT_NS = t.SuperPT_NS,
		MasterPT_NS = t.MasterPT_NS,
		AgentPT_NS = t.AgentPT_NS
	FROM #AgentList l
		INNER JOIN t ON l.custid = t.custid
	
	SELECT @sql = '
	DELETE #AgentList
	WHERE NOT ((SuperPT_SB + MasterPT_SB + AgentPT_SB) BETWEEN ' + CAST(@SB_from AS VARCHAR(10)) + ' AND '+ CAST(@SB_to AS VARCHAR(10)) +' '+
	@FilterPossess + ' (SuperPT_NS + MasterPT_NS + AgentPT_NS) BETWEEN ' + CAST(@NS_from AS VARCHAR(10)) + ' AND ' + CAST(@NS_to AS VARCHAR(10)) +')'
	
	EXEC sp_executesql @sql
	
	SELECT @totalItems = count(1)
	FROM #AgentList
	
	SELECT @sql = '
	;WITH t as (
	SELECT ROW_NUMBER () OVER (ORDER BY ' + 
		CASE @SortBy WHEN 1 THEN 'SuperPT_SB+MasterPT_SB+AgentPT_SB DESC'
					WHEN 2 THEN 'SuperPT_SB+MasterPT_SB+AgentPT_SB ASC'
					WHEN 3 THEN 'SuperPT_NS+MasterPT_NS+AgentPT_NS DESC'
					WHEN 4 THEN 'SuperPT_NS+MasterPT_NS+AgentPT_NS ASC'
					WHEN 5 THEN 's.username ASC, m.username ASC, ag.username ASC'
					WHEN 6 THEN 's.username DESC, m.username DESC, ag.username DESC' 
					ELSE 'ag.username ASC' END +') rn,
		SuperPT_SB+MasterPT_SB+AgentPT_SB as TotalPT_SB,
		SuperPT_NS+MasterPT_NS+AgentPT_NS as TotalPT_NS,			
		ag.custid, ag.username as agent, s.username as super, m.username as master,
		ag.SuperPT_SB, ag.SuperPT_NS, ag.MasterPT_SB, ag.MasterPT_NS, ag.AgentPT_SB, ag.AgentPT_NS,
		ag.status, ag.Danger, ag.isMonitorPT
	FROM #AgentList ag
		INNER JOIN custinfo s WITH(NOLOCK) ON ag.srecommend = s.custid
		INNER JOIN custinfo m WITH(NOLOCK) ON ag.mrecommend = m.custid
	)
	SELECT *
	FROM t 
	WHERE rn BETWEEN '+ CAST(@rowStart AS VARCHAR(10)) + ' AND ' + CAST(@rowEnd AS VARCHAR(10))
	
	EXEC sp_executesql @sql
END
GO	