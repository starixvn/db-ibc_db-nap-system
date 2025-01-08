/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Email_NotificationInfoInsert]
(
	@ActionID INT
	 , @NotificationInfo VARCHAR(MAX) = ''
	 , @CreateDate DATETIME
)
AS
/*
	Created: Helen
	Date: 2017-09-29
	Task: Email Notifications - [Redmine:75557]
	DB: DBCUST/CustDB

	Revisions:
		- 20241230@July: Scale Out DBCUST - Apply Inhouse replication for the remaning tables [Redmine: #215627]
		
	Parameter's explaination: 
*/
BEGIN
	SET NOCOUNT ON
	
	INSERT INTO dbo.EmailNotification (NotificationInfo, CreatedDate, ActionID, RepUpdateTime)
	VALUES (@NotificationInfo, @CreateDate, @ActionID, dbo.f_GetDateTime2())
	
END

GO