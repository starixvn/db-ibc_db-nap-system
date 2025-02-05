/*<info serverAlias="DBGLOB-GlobCustDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_CurrencyGroup_Upd] 
	-- Add the parameters for the stored procedure here
	 @CurrencyGroup VARCHAR(4000)
	,@UserID	INT
	,@IP		VARCHAR(50)		= ''
	,@ErrCode	INT = 0				OUTPUT
	,@ErrMsg	NVARCHAR(4000)	= '' OUTPUT
AS
/*
	Created: 20230914@Tacy
	Task : Nap CM - Non-sport Company Bet Limit Setting - Manage Currency Group
	DB: DBGLOB-GlobCustDB

	Revisions:
		- 20230914@Tacy: Create SP [Redmine: #196256]
		- 20250205@Tacy: Move to GlobCustDB [RedmineID: #216870]
		
	Param's Explanation:
		@CurrencyGroup: 
			**Update:
						'<ROOT>
							<CurrencyGroup CurrencyGroupID= "1" ExchangeIDs = "1,20,8" IsCredit = "0"/>
							<CurrencyGroup CurrencyGroupID= "2" ExchangeIDs = "97" IsCredit = "0"/>
							<CurrencyGroup CurrencyGroupID= "2" ExchangeIDs = "98" IsCredit = "1"/>
							<CurrencyGroup CurrencyGroupID= "3" ExchangeIDs = "99" IsCredit = "1"/>
						</ROOT>'
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT
		, @logSpData NVARCHAR(MAX), @OldlogSpData NVARCHAR(MAX)

	DECLARE @InputTbl TABLE (
			  RowID			TINYINT IDENTITY(1,1)
			, CurrencyGroupID TINYINT
			, ExchangeIDs	VARCHAR(50)
			, IsCredit		BIT
	)

	CREATE TABLE #tmpExchange (CurrencyGroupID TINYINT, ExchangeID INT, IsCredit BIT)
	
	SET @StartRun = GETDATE()	

	--CHECK
	EXEC NAP_CurrencyGroup_Check
			@CurrencyGroup=@CurrencyGroup	
			,@IsUpdate=1
			,@ErrCode=@ErrCode	OUTPUT
			,@ErrMsg=@ErrMsg OUTPUT

	IF @ErrCode<>0 RETURN

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

	INSERT INTO #tmpExchange (CurrencyGroupID, ExchangeID, IsCredit)
	SELECT i.CurrencyGroupID, ss.ExchangeID, i.IsCredit
	FROM @InputTbl i
	CROSS APPLY (SELECT CAST(TRIM(VALUE) AS INT) AS ExchangeID
				 FROM string_split(i.ExchangeIDs,',')
				 WHERE TRIM(VALUE)>''
				 ) ss

	--Get old value
	SELECT @OldLogSpData = (
				SELECT t.CurrencyGroupID
					, (SELECT STUFF((SELECT ',' + CAST(ExchangeId AS VARCHAR(5))
									 FROM exchange e WITH (NOLOCK)
									 WHERE (IsCredit=1 AND CreditGroupID=t.CurrencyGroupID)
										OR (IsCredit=0 AND LicenseeGroupID=t.CurrencyGroupID)
									 FOR XML PATH('')),1,1,''))
						AS ExchangeIDs
					, t.IsCredit
				FROM #tmpExchange t
				GROUP BY t.CurrencyGroupID, t.IsCredit
				FOR XML RAW ('CurrencyGroup'), ROOT('ROOT')
				)

	IF EXISTS (SELECT TOP 1 1 FROM #tmpExchange WHERE IsCredit=1)
	BEGIN
		-- remove Currency
		UPDATE e
		SET CreditGroupID=NULL
			,RepUpdateTime=dbo.f_GetDateTime2()
		FROM exchange e WITH (ROWLOCK, UPDLOCK)
		CROSS APPLY (SELECT TOP 1 1 AS val
					 FROM #tmpExchange t
					 WHERE t.CurrencyGroupID=e.CreditGroupID
						AND t.IsCredit=1) t
		LEFT JOIN #tmpExchange tt
				ON tt.ExchangeID=e.ExchangeId AND tt.IsCredit=1
		WHERE tt.ExchangeId IS NULL 

		UPDATE E
		SET CreditGroupID=t.CurrencyGroupID
		  , RepUpdateTime=dbo.f_GetDateTime2()
		FROM exchange e WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tmpExchange t ON e.ExchangeId=t.ExchangeID
		WHERE t.IsCredit=1

		DELETE FROM #tmpExchange WHERE IsCredit=1
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM #tmpExchange WHERE IsCredit=0)
	BEGIN
		-- remove Currency
		UPDATE e
		SET LicenseeGroupID=NULL
			,RepUpdateTime=dbo.f_GetDateTime2()
		FROM exchange e WITH (ROWLOCK, UPDLOCK)
		CROSS APPLY (SELECT TOP 1 1 AS val
					 FROM #tmpExchange t
					 WHERE t.CurrencyGroupID=e.LicenseeGroupID) t
		LEFT JOIN #tmpExchange tt
				ON tt.ExchangeID=e.ExchangeId
		WHERE tt.ExchangeId IS NULL 

		UPDATE E
		SET LicenseeGroupID=t.CurrencyGroupID
		  , RepUpdateTime=dbo.f_GetDateTime2()
		FROM exchange e WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tmpExchange t ON e.ExchangeId=t.ExchangeID
	END

	--Write log
	SELECT	@duration = DATEDIFF(MILLISECOND, @startRun, GETDATE())

	DECLARE @NewLog VARCHAR(MAX)

	SET @NewLog = '<NAP_CurrencyGroup_Upd IP="'+ COALESCE(CAST(@IP AS VARCHAR(15)),SPACE(1))+'" >'

	SELECT @logSpData = REPLACE(REPLACE(@CurrencyGroup, '<ROOT>', @NewLog),'/ROOT','/NAP_CurrencyGroup_Upd')
	SELECT @OldlogSpData = REPLACE(REPLACE(@OldlogSpData, '<ROOT>', @NewLog),'/ROOT','/NAP_CurrencyGroup_Upd')

	EXEC  Acc_WriteLog_UserLog_RunSP_Wrapper
				@UserID = @UserID,
				@ActionID = 31778,
				@TrackingValue = @LogSPData,
				@TrackingValue2 = @OldlogSpData,
				@duration = @Duration
END
GO