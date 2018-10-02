/*<info serverAlias="DBNAP-bodb_NAPLOG" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_LogExecSp_GetById]
	@LogId INT
AS
/*  
 * Created: 20120820@Edward
 * Task : Get execute SP log by log ID
 * DB: DBNAP-bodb_NAPLOG
 *  
 * Revisions:     
	- 20180925@Helen: DB052.bodb_NAP Migration, Move to bodb_NAPLOG - [Redmine:100493]
	
 * Param's Explanation: 
*/
BEGIN
	SET NOCOUNT ON

	SELECT ld.ID,
		ld.ActionID,
		ld.Data,
		ld.OldData,
		la.Items,
		la.SubItems
	FROM dbo.NAPLOG_RUNSP_Detail AS ld WITH (NOLOCK)
		INNER JOIN dbo.NAPLog_Action AS la WITH (NOLOCK) ON ld.ActionId=la.ActionId
	WHERE ld.ID = @LogId
END

GO
GRANT EXECUTE ON [dbo].[NAP_LogExecSp_GetById] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_LogExecSp_GetById] TO [vnteam] AS [dbo]