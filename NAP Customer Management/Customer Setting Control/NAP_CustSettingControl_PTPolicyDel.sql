ALTER PROCEDURE [dbo].[NAP_CustSettingControl_PTPolicyDel]
	  @SiteID			INT = NULL
	, @ExchangeID		INT = NULL
	, @userid		INT
	, @IP			VARCHAR(50)
	, @ErrCode		INT = 0 OUTPUT
	, @ErrMsg		VARCHAR(500) = '' OUTPUT
AS 
/*	Created by: Dominic
	Date: 20141225
	Task: Delte PT Policy by Site and Currency
	DB: DBACC/bodb02
	*Parameters:

	*Revisions:
		
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @startRun	DATETIME,
			@endRun		DATETIME,
			@duration	INT
	SET	@startRun = GETDATE()
	
	SELECT @ErrCode = 0, @ErrMsg = ''
	
	--Delete PT Policy
	DELETE FROM dbo.PTSettingPolicy 
	WHERE (@SiteID IS NULL OR SiteID = @SiteID)
			AND 
			(@ExchangeID IS NULL OR ExchangeID = @ExchangeID)
	
	IF @@ERROR <> 0
	BEGIN		
		SELECT @ErrMsg = 'Remove Position Taking Policy unsuccessfuly!',
			@ErrCode = 102
		RETURN
	END
	
	DECLARE @LogData NVARCHAR(4000)
	SELECT @LogData = '<NAP_CustSettingControl_PTPolicyDel ' 										
					+ 'SiteID="' + coalesce(cast(@SiteID AS VARCHAR(50)), space(1)) + '" ' 
					+ 'ExchangeID="' + coalesce(cast(@ExchangeID AS VARCHAR(50)), space(1)) + '" ' 
					+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
					
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
		@Userid = @userid,
		@ActionID = 31101,
		@TrackingValue = @LogData,
		@Duration = @duration

END
