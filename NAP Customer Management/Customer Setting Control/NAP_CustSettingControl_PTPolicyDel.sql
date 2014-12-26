ALTER PROCEDURE [dbo].[NAP_CustSettingControl_PTPolicyDel]
	  @SiteID		INT = 1
	, @ExchangeID	INT = 1
	, @RoleID		INT = 5
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
			
	DECLARE @OldPTPolicy TABLE (
		[ProductID] TINYINT
		, [SuperMax] SMALLMONEY
		, [MasterMax] SMALLMONEY
		, [AgentMax] SMALLMONEY
		)
		
	SET	@startRun = GETDATE()
	
	SELECT @ErrCode = 0, @ErrMsg = ''
	
	
	--Get old values
	IF @RoleID = 4
	BEGIN
		--Get old values
		INSERT INTO @OldPTPolicy
		SELECT p.ProductID,ISNULL(p.SuperMax,0),ISNULL(p.MasterMax,0),ISNULL(p.AgentMax,0)
		FROM dbo.PTSettingPolicy p
		WHERE p.SiteID = @SiteID
			AND p.ExchangeID = @ExchangeID
			AND p.RoleID = @RoleID
		
	END
	ELSE IF @RoleID = 3
	BEGIN
		--Get old values
		INSERT INTO @OldPTPolicy
		SELECT p.ProductID,p.SuperMax,ISNULL(p.MasterMax,0),p.AgentMax
		FROM dbo.PTSettingPolicy p
		WHERE p.SiteID = @SiteID
			AND p.ExchangeID = @ExchangeID
			AND p.RoleID = @RoleID
		
	END
	ELSE IF @RoleID = 2
	BEGIN
		--Get old values
		INSERT INTO @OldPTPolicy
		SELECT p.ProductID,p.SuperMax,p.MasterMax,ISNULL(p.AgentMax,0)
		FROM dbo.PTSettingPolicy p
		WHERE p.SiteID = @SiteID
			AND p.ExchangeID = @ExchangeID
			AND p.RoleID = @RoleID
		
	END
	
	
	--Delete PT Policy
	DELETE FROM dbo.PTSettingPolicy 
	WHERE SiteID = @SiteID
			AND ExchangeID = @ExchangeID
			AND RoleID = @RoleID
			
	
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
					+ 'RoleID="'+ coalesce(cast(@RoleID AS VARCHAR(50)), space(1)) + '" ' 
					+ 'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
	
	
	DECLARE @LogOldData NVARCHAR(4000)
	
	DECLARE @OldVariables NVARCHAR(4000) = ''

	SELECT @OldVariables = @OldVariables + ' ' + VarialeName 
						+ CAST(ProductID AS VARCHAR(5)) + '="' 
						+ CASE WHEN Value=0 THEN '' ELSE CAST(Value AS VARCHAR(15)) END + '"'
	FROM @OldPTPolicy
	UNPIVOT(Value FOR VarialeName IN (SuperMax, MasterMax, AgentMax)) u;

	SELECT @LogOldData = '<NAP_CustSettingControl_PTPolicyDel ' 
					+ 'SiteID="' + coalesce(cast(@SiteID AS VARCHAR(50)), space(1)) + '" ' 
					+ 'ExchangeID="' + coalesce(cast(@ExchangeID AS VARCHAR(50)), space(1)) + '" ' 
					+ 'RoleID="'+ coalesce(cast(@RoleID AS VARCHAR(50)), space(1)) + '" ' 
					+ @OldVariables + ' ' 
					+ 'IP="' + COALESCE(@IP, SPACE(1)) 
					+ '" />'
									
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF(millisecond,@startRun,@endRun)
	
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
		@Userid = @userid,
		@ActionID = 31101,
		@TrackingValue = @LogData,
		@TrackingValue2 = @LogOldData,
		@Duration = @duration

END
