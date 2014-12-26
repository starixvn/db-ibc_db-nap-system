ALTER PROCEDURE [dbo].[NAP_CustSettingControl_PTPolicyUpd] 
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
	Task: UPDATE PT Policy by Site and Currency
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

	--Update changed Policy
	IF @RoleID = 4
	BEGIN
		UPDATE main
		SET main.SuperMax = n.SuperMax
			, main.MasterMax = n.MasterMax
			, main.AgentMax = n.AgentMax
		FROM dbo.PTSettingPolicy main WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @NewPTPolicy n
			ON main.ProductID = n.ProductID
		WHERE main.SiteID = @SiteID
			AND main.ExchangeID = @ExchangeID
			AND main.RoleID = @RoleID
	END
	ELSE IF @RoleID = 3
	BEGIN
		UPDATE main
		SET main.MasterMax = n.MasterMax
		FROM dbo.PTSettingPolicy main WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @NewPTPolicy n
			ON main.ProductID = n.ProductID
		WHERE main.SiteID = @SiteID
			AND main.ExchangeID = @ExchangeID
			AND main.RoleID = @RoleID
	END
	ELSE IF @RoleID = 2
	BEGIN
		UPDATE main
		SET main.AgentMax = n.AgentMax
		FROM dbo.PTSettingPolicy main WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @NewPTPolicy n
			ON main.ProductID = n.ProductID
		WHERE main.SiteID = @SiteID
			AND main.ExchangeID = @ExchangeID
			AND main.RoleID = @RoleID
	END

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrMsg = 'Remove Position Taking Policy unsuccessfuly!'
			, @ErrCode = 102

		RETURN
	END

	--Write log with current format
	DECLARE @Variables NVARCHAR(4000) = ''

	SELECT @Variables = @Variables + ' ' + VarialeName 
						+ CAST(ProductID AS VARCHAR(5)) + '="' 
						+ CAST(Value AS VARCHAR(15)) + '"'
	FROM @NewPTPolicy
	UNPIVOT(Value FOR VarialeName IN (SuperMax, MasterMax, AgentMax)) u;

	DECLARE @LogData NVARCHAR(4000)

	SELECT @LogData = '<NAP_CustSettingControl_PTPolicyUpd ' 
					+ 'SiteID="' + coalesce(cast(@SiteID AS VARCHAR(50)), space(1)) + '" ' 
					+ 'ExchangeID="' + coalesce(cast(@ExchangeID AS VARCHAR(50)), space(1)) + '" ' 
					+ 'RoleID="'+ coalesce(cast(@RoleID AS VARCHAR(50)), space(1)) + '" ' 
					+ @Variables + ' ' 
					+ 'IP="' + COALESCE(@IP, SPACE(1)) 
					+ '" />'

	SELECT @LogData

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)

	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP @Userid = @userid
		, @ActionID = 31102
		, @TrackingValue = @LogData
		, @Duration = @duration
END
