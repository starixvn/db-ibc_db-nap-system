/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE CustDB
GO

 ALTER PROCEDURE [dbo].[Nap_CustomerDelSmartPunter]
	@custid		INT,
	@userid		INT,
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
/*
	Created: Johnson
	Date: 2014-06-11
	Task: Remove customer out of smart punter list
	DB: DBTXN/CustDB
	
	Revisions:
	
	Paramter's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT
	SET	@startRun = GETDATE()
	
	--Check permission
	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@userid,@funcname='[SmartPunter]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
		
	IF NOT EXISTS (SELECT 1 FROM SmartPunterList WITH (NOLOCK) WHERE CustID = @CustID)
	BEGIN		
		SELECT @ErrMsg = 'This account doesn''t exist in the list.',
			@ErrCode = 101
		RETURN
	END		
	
	DELETE SmartPunterList  WITH (ROWLOCK) WHERE CustID = @CustID
			
	IF @@ERROR <> 0
	BEGIN		
		SELECT @ErrMsg = 'Remove smart punter unsuccessfuly!',
			@ErrCode = 102
		RETURN
	END
	
	-- write log
	DECLARE @LogData NVARCHAR(4000)
	SELECT @LogData = '<Nap_CustomerDelSmartPunter custid="'+ coalesce(cast(@custid as varchar(20)),space(1)) + '" '												
					+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '												
					+ 'ErrMsg="' + coalesce(@ErrMsg,space(1))+'" '
					+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
					
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@Userid = @userid,
			@Custid = @CustID,
			@ActionID = 31002,
			@TrackingValue = @LogData,
			@Duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @LogData = '<Nap_CustomerDelSmartPunter custid="' + coalesce(cast(@custid as varchar(20)),space(1)) + '" '												
					+ 'ErrCode="' + coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" '												
					+ 'ErrMsg="' + coalesce(ERROR_MESSAGE(),space(1))+'" '
					+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
					
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
			@Userid = @userid,
			@Custid = @CustID,
			@ActionID = 31002,
			@TrackingValue = @LogData,
			@Duration = @duration
	END CATCH
END
GO



 