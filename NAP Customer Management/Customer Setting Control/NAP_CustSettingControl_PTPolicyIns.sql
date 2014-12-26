ALTER PROCEDURE [dbo].[NAP_CustSettingControl_PTPolicyIns] 
	  @SiteID INT = 1
	, @ExchangeID	INT = 1
	, @RoleID		INT = 5
	, @PTPolicy_XML VARCHAR(MAX) = ''
	, @userid		INT
	, @IP			VARCHAR(50)
	, @ErrCode		INT = 0 OUTPUT
	, @ErrMsg		VARCHAR(500) = '' OUTPUT
AS
/*	Created by: Dominic
	Date: 20141225
	Task: Insert New PT Policy
	DB: DBACC/bodb02
	*Parameters:
		• @PTPolicy_XML:
			<ROOT>
					<Policy 
							ProductID="1" 
							SuperMax="0.85"
							MasterMax="0.8"
							AgentMax="0.85"
					/>
			</ROOT>
	*Revisions:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @startRun DATETIME
		, @endRun DATETIME
		, @duration INT
	DECLARE @iDoc INT
	DECLARE @NewPTPolicy TABLE (
		[ProductID] TINYINT
		, [SuperMax] SMALLMONEY
		, [MasterMax] SMALLMONEY
		, [AgentMax] SMALLMONEY
		)

	SET @startRun = GETDATE()

	IF @PTPolicy_XML IS NULL
		OR @PTPolicy_XML = ''
	BEGIN
		SELECT @ErrMsg = 'Invalid Parameter'
			, @ErrCode = 101

		RETURN
	END

	SELECT @ErrCode = 0
		, @ErrMsg = ''

	EXEC sp_xml_preparedocument @iDoc OUTPUT
		, @PTPolicy_XML

	INSERT @NewPTPolicy
	SELECT ProductID
		, CAST(SuperMax AS SMALLMONEY) AS SuperMax
		, CAST(MasterMax AS SMALLMONEY) AS MasterMax
		, CAST(AgentMax AS SMALLMONEY) AS AgentMax 
	FROM OPENXML(@iDoc, '/ROOT/Policy', 1) WITH (
			SiteID INT
			, ExchangeID INT
			, RoleID TINYINT
			, ProductID TINYINT
			, SuperMax VARCHAR(15)
			, MasterMax VARCHAR(15)
			, AgentMax VARCHAR(15)
			)

	EXEC sp_xml_removedocument @iDoc

	--Check If new PT Policy is existing
	IF EXISTS (SELECT TOP 1 1
	FROM dbo.PTSettingPolicy o WITH(NOLOCK)
	JOIN @NewPTPolicy n ON o.ProductID = n.ProductID
	WHERE o.SiteID = @SiteID
		AND o.ExchangeID = @ExchangeID
		AND o.RoleID = @RoleID)
	BEGIN
		SELECT @ErrMsg = 'PT Policy already exists!'
			, @ErrCode = 102

		RETURN
	END
	
	--Insert new PT Policy
	INSERT INTO dbo.PTSettingPolicy
	SELECT
		@SiteID
		, @ExchangeID
		, @RoleID
		, n.ProductID
		, CASE WHEN ISNULL(n.SuperMax,0)=0 THEN NULL ELSE n.SuperMax END
		, CASE WHEN ISNULL(n.MasterMax,0)=0 THEN NULL ELSE n.MasterMax END
		, CASE WHEN ISNULL(n.AgentMax,0)=0 THEN NULL ELSE n.AgentMax END
	FROM @NewPTPolicy n

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrMsg = 'Add new Position Taking Policy unsuccessfuly!'
			, @ErrCode = 103

		RETURN
	END

	--Write log with current format
	DECLARE @Variables NVARCHAR(4000) = ''

	SELECT @Variables = @Variables + ' ' + VarialeName 
						+ CAST(ProductID AS VARCHAR(5)) + '="' 
						+ CASE WHEN Value=0 THEN '' ELSE CAST(Value AS VARCHAR(15)) END + '"'
	FROM @NewPTPolicy
	UNPIVOT(Value FOR VarialeName IN (SuperMax, MasterMax, AgentMax)) u;

	DECLARE @LogData NVARCHAR(4000)

	SELECT @LogData = '<NAP_CustSettingControl_PTPolicyIns ' 
					+ 'SiteID="' + coalesce(cast(@SiteID AS VARCHAR(50)), space(1)) + '" ' 
					+ 'ExchangeID="' + coalesce(cast(@ExchangeID AS VARCHAR(50)), space(1)) + '" ' 
					+ 'RoleID="'+ coalesce(cast(@RoleID AS VARCHAR(50)), space(1)) + '" ' 
					+ @Variables + ' ' 
					+ 'IP="' + COALESCE(@IP, SPACE(1)) 
					+ '" />'

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)

	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP @Userid = @userid
		, @ActionID = 31103
		, @TrackingValue = @LogData
		, @Duration = @duration
END
