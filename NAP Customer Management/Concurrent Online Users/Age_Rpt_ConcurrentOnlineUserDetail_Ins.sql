/*<info serverAlias="DBONUSER-ON_USER" executers="bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Age_Rpt_ConcurrentOnlineUserDetail_Ins
	@XmlData	XML
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20230323@Malcolm
	Task : Insert Concurrent Online Users Detail [RedmineID: #183462]
	DB: DBONUSER/ON_USER

	Revisions:
		- 20230323@Malcolm: Initial SPs [redmine:#183462]

	Param's Explanation:
		- @XMLData : '<root>
							<r CreatedDate="" SiteId="" RoleId="" RealUserCount="" TestingUserCount=""/>
					  </root>''
*/
BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		INSERT INTO dbo.ConcurrentOnlineUserDetail (CreatedDate, Siteid, RoleId, RealUserCount, TestingUserCount)
		SELECT 
			t.c.value('@CreatedDate', 'DATETIME')	AS CreatedDate
			,t.c.value('@SiteId', 'INT')			AS Siteid
			,t.c.value('@RoleId', 'TINYINT')		AS RoleId
			,t.c.value('@RealUserCount', 'INT')		AS RealUserCount
			,t.c.value('@TestingUserCount', 'INT')	AS TestingUserCount
		FROM @XmlData.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@XmlData = NULL))
	END TRY
	BEGIN CATCH 
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
	
END