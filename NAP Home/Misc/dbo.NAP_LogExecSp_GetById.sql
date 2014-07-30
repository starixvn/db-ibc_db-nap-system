 ALTER PROCEDURE [dbo].[NAP_LogExecSp_GetById]
	@LogId INT
AS
/*  
 * Created: 20120820@Edward
 * Task : Get execute SP log by log ID
 * DB: bodb_NAP
 *  
 * Revisions:     
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
	FROM bodb_NAPLog.dbo.NAPLOG_RUNSP_Detail AS ld WITH (NOLOCK)
	INNER JOIN  bodb_NAPLog.dbo.NAPLog_Action AS la WITH (NOLOCK) ON ld.ActionId=la.ActionId
	WHERE ld.ID = @LogId
END


GO
GRANT EXECUTE ON [dbo].[NAP_LogExecSp_GetById] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_LogExecSp_GetById] TO [vnteam] AS [dbo]