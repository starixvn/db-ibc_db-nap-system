/*<info serverAlias="DBPOL-NAP_UserControl" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Task_NAP_ClearLogin]
AS

/*
	Created: 20240502@Kos
	Task: NAP System Configuarion - Clear inactive login
	DB: DBPOL.NAP_UserControl

	Revisions:
		- 20240502@Kos: Clear inactive login [Redmine: #203053]
*/

BEGIN
	SET NOCOUNT ON

	DELETE FROM NAP_OnUser WITH (UPDLOCK, ROWLOCK)
	WHERE ReloadTime < DATEADD(DAY, -1, CURRENT_TIMESTAMP)
		OR IsKickedOut = 1
END
GO
