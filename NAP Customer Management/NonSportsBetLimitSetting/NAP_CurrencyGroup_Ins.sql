/*<info serverAlias="DBGLOB-GlobCustDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_CurrencyGroup_Ins] 
	-- Add the parameters for the stored procedure here
	 @CurrencyGroup VARCHAR(4000)
	,@UserID	INT
	,@IP		VARCHAR(50)		= ''
	,@ErrCode	INT = 0				OUTPUT
	,@ErrMsg	NVARCHAR(4000)	= '' OUTPUT
AS
/*
	Created: 20231117@Tacy
	Task : Nap CM - Non-sport Company Bet Limit Setting - Manage Currency Group
	DB: DBGLOB-GlobCustDB

	Revisions:
		- 20231117@Tacy: Create SP [Redmine: #196256]
		- 20250205@Tacy: Move to GlobCustDB [RedmineID: #216870]
		
	Param's Explanation:
		@CurrencyGroup: 
			**Add new:
						'<ROOT>
							<CurrencyGroup CurrencyGroupID= "" ExchangeIDs = "1,20,8" IsCredit = "0"/>
							<CurrencyGroup CurrencyGroupID= "" ExchangeIDs = "97" IsCredit = "0"/>
							<CurrencyGroup CurrencyGroupID= "" ExchangeIDs = "98" IsCredit = "1"/>
							<CurrencyGroup CurrencyGroupID= "" ExchangeIDs = "99" IsCredit = "1"/>
						</ROOT>'
*/
BEGIN
	SET NOCOUNT ON;

	IF ISNULL(@CurrencyGroup,'')=''	RETURN

	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @logSpData NVARCHAR(MAX)
		, @MaxCreditGroupID TINYINT, @MaxLicenseeGroupID TINYINT
	
	SET @StartRun = GETDATE()	

	--CHECK
	EXEC NAP_CurrencyGroup_Check
			@CurrencyGroup=@CurrencyGroup	
			,@IsUpdate=0
			,@ErrCode=@ErrCode	OUTPUT
			,@ErrMsg=@ErrMsg OUTPUT

	IF @ErrCode<>0 RETURN

	DECLARE @InputTbl TABLE (
			  RowID				TINYINT IDENTITY(1,1)
			, CurrencyGroupID	TINYINT
			, ExchangeIDs		VARCHAR(50)
			, IsCredit			BIT
	)

	CREATE TABLE #tmpExchange (CurrencyGroupID TINYINT, ExchangeID INT, IsCredit BIT)

	--Parse XML data
	DECLARE @iDoc INT
	BEGIN TRY
		EXEC sp_xml_preparedocument @iDoc OUTPUT
			, @CurrencyGroup

		INSERT INTO @InputTbl(CurrencyGroupID, ExchangeIDs, IsCredit)
		SELECT	CASE WHEN ISNUMERIC(CurrencyGroupID)=0 THEN NULL ELSE CurrencyGroupID END CurrencyGroupID
			, CASE WHEN LEN(ExchangeIDs)=0 THEN NULL ELSE ExchangeIDs END ExchangeIDs
			, IsCredit
		FROM OPENXML(@iDoc, '/ROOT/CurrencyGroup', 1) WITH (
				  CurrencyGroupID	VARCHAR(10)
				, ExchangeIDs		VARCHAR(50)
				, IsCredit			BIT
		)

		EXEC sp_xml_removedocument @iDoc
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE();		
		RETURN
	END CATCH

	--Get current CurrencyGroupID
	SELECT @MaxCreditGroupID=MAX(CreditGroupID)
		, @MaxLicenseeGroupID=MAX(LicenseeGroupID)
	FROM Exchange WITH (NOLOCK)

	INSERT INTO #tmpExchange (CurrencyGroupID, ExchangeID, IsCredit)
	SELECT CASE WHEN IsCredit=1 THEN @MaxCreditGroupID ELSE @MaxLicenseeGroupID END
			+ RowID
		, ss.ExchangeID, i.IsCredit
	FROM @InputTbl i
	CROSS APPLY (SELECT CAST(TRIM(VALUE) AS INT) AS ExchangeID
				 FROM string_split(i.ExchangeIDs,',')
				 WHERE TRIM(VALUE)>''
				 ) ss
				 
	BEGIN TRY
		UPDATE E
		SET CreditGroupID=t.CurrencyGroupID
		  , RepUpdateTime=dbo.f_GetDateTime2()
		FROM exchange e WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tmpExchange t ON e.ExchangeId=t.ExchangeID
		WHERE t.IsCredit=1

		UPDATE E
		SET LicenseeGroupID=t.CurrencyGroupID
		  , RepUpdateTime=dbo.f_GetDateTime2()
		FROM exchange e WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tmpExchange t ON e.ExchangeId=t.ExchangeID
		WHERE t.IsCredit=0
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE();		
		RETURN
	END CATCH

	--Write log
	SELECT	@duration = DATEDIFF(MILLISECOND, @startRun, GETDATE())

	DECLARE @NewLog VARCHAR(MAX)

	SET @NewLog = '<NAP_CurrencyGroup_Ins IP="'+ COALESCE(CAST(@IP AS VARCHAR(15)),SPACE(1))+'" >'
	SELECT @logSpData = REPLACE(REPLACE(@CurrencyGroup, '<ROOT>', @NewLog),'/ROOT','/NAP_CurrencyGroup_Ins')

	EXEC  Acc_WriteLog_UserLog_RunSP_Wrapper
				@UserID = @UserID,
				@ActionID = 31777,
				@TrackingValue = @LogSPData,
				@duration = @Duration
END
GO