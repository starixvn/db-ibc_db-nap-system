/*<info serverAlias="DBWH-bodb_account" executers="vngrafana" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Acc_Grafana_OnlineAgentDetail_Ins(
	 @XmlData	XML
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	NVARCHAR(MAX) = '' OUTPUT
)
AS
/*
    Created: 20251114@Eden  
	Task : Schedule service, every minute - insert data Users Online for OnlineAgentDetail table
	DB: DBWH-bodb_account
  
	Revisions:
		- 20251114@Eden: Alpha - Dashboard for Users Online [Redmine: #244197] 

	Parameter's Explaination:
		@XmlData = : 
				<root>
					<r CreatedDate="2023-03-23 10:30:00" SiteId="1" RoleId="2" RealUserCount="150" TestingUserCount="25"/>
					<r CreatedDate="2023-03-23 10:30:00" SiteId="1" RoleId="3" RealUserCount="200" TestingUserCount="30"/>
					<r CreatedDate="2023-03-23 10:30:00" SiteId="1" RoleId="4" RealUserCount="100" TestingUserCount="50"/>
					<r CreatedDate="2023-03-23 10:30:00" SiteId="11" RoleId="2" RealUserCount="150" TestingUserCount="25"/>
					<r CreatedDate="2023-03-23 10:30:00" SiteId="11" RoleId="3" RealUserCount="200" TestingUserCount="30"/>
					<r CreatedDate="2023-03-23 10:30:00" SiteId="11" RoleId="4" RealUserCount="110" TestingUserCount="45"/>
				</root>
			
	Examples:
		DECLARE @ErrCode	INT 
			,@ErrMsg NVARCHAR(MAX) 
		EXEC Acc_Grafana_OnlineAgentDetail_Ins 
			@XmlData = '<root>
					<r CreatedDate="2023-03-23 10:30:00" SiteId="1" RoleId="2" RealUserCount="150" TestingUserCount="25"/>
					<r CreatedDate="2023-03-23 10:30:00" SiteId="1" RoleId="3" RealUserCount="200" TestingUserCount="30"/>
					<r CreatedDate="2023-03-23 10:30:00" SiteId="1" RoleId="4" RealUserCount="100" TestingUserCount="50"/>
					<r CreatedDate="2023-03-23 10:30:00" SiteId="11" RoleId="2" RealUserCount="150" TestingUserCount="25"/>
					<r CreatedDate="2023-03-23 10:30:00" SiteId="11" RoleId="3" RealUserCount="200" TestingUserCount="30"/>
					<r CreatedDate="2023-03-23 10:30:00" SiteId="11" RoleId="4" RealUserCount="110" TestingUserCount="45"/>
				</root>',
			@ErrCode = @ErrCode OUT,
			@ErrMsg = @ErrMsg OUT
		SELECT @ErrCode, @ErrMsg
		
	
*/
BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		INSERT INTO dbo.OnlineAgentDetail (CreatedDate, Siteid, RoleId, UserCount)
		SELECT 
			 DATEADD(HOUR, -12, t.c.value('@CreatedDate', 'SMALLDATETIME'))	AS CreatedDate -- Convert to GMT-4
			,t.c.value('@SiteId', 'INT')			AS Siteid
			,t.c.value('@RoleId', 'TINYINT')		AS RoleId
			,t.c.value('@RealUserCount', 'INT')	+ t.c.value('@TestingUserCount', 'INT')	AS UserCount
		FROM @XmlData.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@XmlData = NULL))
	END TRY
	BEGIN CATCH 
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
END
GO