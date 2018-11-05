/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_StatusLog_CreditCollection_List] 
	@Code 				VARCHAR(30) = '',
	@PageSize	 		INT = -1,
	@PageIndex	 		INT = -1,
	@TotalRows			INT = 0 OUTPUT
AS
/*
	Created: Louis
	Date: 2018-11-05
	Task: Credit Collection Summary
	DB: DBLOG/bodb_CustomerLog

	Revisions:
		--20181105@Louis: Credit Collection Summary  [RedmineID: #98621]
	Parameter's explaination: 
		• @PageIndex: start from 1, -1 when get all data to export excel		
*/

BEGIN
	SET NOCOUNT ON	
	
	DECLARE @lowerBound INT, @upperbound INT	
	SET @lowerBound = (@PageIndex - 1) * @PageSize   
	SET @upperbound = @lowerBound + @PageSize 	
	
	SELECT LogID, LogDate, ActionID, TrackingValue, TrackingValue2, EditorId, EditorName, CustId, CustName, ActionNameEN, SPName
	FROM (
		SELECT ROW_NUMBER() OVER (ORDER BY lg.LogDate DESC) AS RowNum, lg.LogID, lg.LogDate, lg.ActionID, lg.TrackingValue, lg.TrackingValue2
			,editor.CustId AS EditorId, editor.Username AS EditorName
			,cust.CustId, cust.Username AS CustName
			,act.ActionNameEN, act.SPName		
		FROM UserLog_RunSP lg 
			JOIN bodb02.dbo.Customer cust ON lg.CustID = cust.CustId AND (@Code = '' OR cust.Username like '%' + @Code + '%')
			LEFT JOIN bodb02.dbo.Customer editor ON lg.UserId = editor.CustId
			LEFT JOIN LogAction act ON act.ActionId = lg.ActionId	
		WHERE lg.Actionid BETWEEN 1166 AND 1168
	) AS logs
	WHERE (@PageSize = -1 OR RowNum BETWEEN @lowerBound AND @upperbound)
	
	
	SELECT @TotalRows = Count(LogID)
	FROM (
		SELECT ROW_NUMBER() OVER (ORDER BY lg.LogDate DESC) AS RowNum, lg.LogID, lg.LogDate, lg.ActionID, lg.TrackingValue, lg.TrackingValue2
			,editor.CustId AS EditorId, editor.Username AS EditorName
			,cust.CustId, cust.Username AS CustName
			,act.ActionNameEN, act.SPName		
		FROM UserLog_RunSP lg 
			JOIN bodb02.dbo.Customer cust ON lg.CustID = cust.CustId AND (@Code = '' OR cust.Username like '%' + @Code + '%')
			LEFT JOIN bodb02.dbo.Customer editor ON lg.UserId = editor.CustId
			LEFT JOIN LogAction act ON act.ActionId = lg.ActionId	
		WHERE lg.Actionid BETWEEN 1166 AND 1168
	) AS logs	
END

GO




