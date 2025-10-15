/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_CurrencyGroup_Check] 
	-- Add the parameters for the stored procedure here
	 @CurrencyGroup VARCHAR(4000)
	,@IsUpdate		BIT=0
	,@ErrCode		INT = 0				OUTPUT
	,@ErrMsg		NVARCHAR(4000)	= '' OUTPUT
AS
/*
	Created: 20231117@Tacy
	Task : Nap CM - Non-sport Company Bet Limit Setting - Manage Currency Group
	DB: DBCUST-CustDB

	Revisions:
		- 20231117@Tacy: Create SP [Redmine: #196256]
		
	Param's Explanation:
		@CurrencyGroup: 
			**Add new:
						'<ROOT>
							<CurrencyGroup CurrencyGroupID= "" ExchangeIDs = "1,20,8" IsCredit = "0"/>
							<CurrencyGroup CurrencyGroupID= "" ExchangeIDs = "97" IsCredit = "0"/>
							<CurrencyGroup CurrencyGroupID= "" ExchangeIDs = "98" IsCredit = "1"/>
							<CurrencyGroup CurrencyGroupID= "" ExchangeIDs = "99" IsCredit = "1"/>
						</ROOT>'

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

	DECLARE @InputTbl TABLE (
			  RowID			TINYINT IDENTITY(1,1)
			, CurrencyGroupID TINYINT
			, ExchangeIDs	VARCHAR(50)
			, IsCredit		BIT
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

	--check: required field
	SELECT TOP (1)
			@ErrCode=CASE WHEN CurrencyGroupID IS NULL AND @IsUpdate=1	THEN 101
						  WHEN ExchangeIDs IS NULL						THEN 102
						  ELSE 100
				END,
			@ErrMsg=CASE WHEN CurrencyGroupID IS NULL AND @IsUpdate=1	THEN 'The Currency Group is required field.'
						 WHEN ExchangeIDs IS NULL						THEN 'The ExchangeID is required field.'
						 ELSE ''
				END
	FROM @InputTbl
	WHERE CurrencyGroupID IS NULL AND @IsUpdate=1
		OR ExchangeIDs IS NULL

	IF @ErrCode<>0	RETURN

	INSERT INTO #tmpExchange (CurrencyGroupID, ExchangeID, IsCredit)
	SELECT CASE WHEN @IsUpdate=1 THEN CurrencyGroupID ELSE RowID END
		, ss.ExchangeID, i.IsCredit
	FROM @InputTbl i
	CROSS APPLY (SELECT CAST(TRIM(VALUE) AS INT) AS ExchangeID
				 FROM STRING_SPLIT(i.ExchangeIDs,',')
				 WHERE TRIM(VALUE)>''
				 ) ss

	--Not exist currency
	SELECT TOP 1
		@ErrCode=103,
		@ErrMsg= CASE WHEN t.IsCredit = 1 THEN 'The Credit Currency ID ' ELSE 'The Deposit Currency ID ' END
					+ CAST(t.ExchangeID AS VARCHAR(5)) + ' does not exist.'
	FROM #tmpExchange t
	LEFT JOIN exchange e WITH (NOLOCK) ON e.ExchangeId=t.ExchangeID
	WHERE e.ExchangeID IS NULL

	IF @ErrCode<>0 RETURN

	--Inactive currency
	SELECT TOP 1
		@ErrCode=109,
		@ErrMsg= CASE WHEN t.IsCredit = 1 THEN 'The Credit Currency ' ELSE 'The Deposit Currency ' END
					+ e.currency + ' does not active.'
	FROM #tmpExchange t
	INNER JOIN exchange e WITH (NOLOCK) ON e.ExchangeId=t.ExchangeID
	WHERE e.IsActive=0

	IF @ErrCode<>0 RETURN

	--exists in other group
	IF @IsUpdate=0 --NEW
	BEGIN
		SELECT TOP 1
			@ErrCode=105,
			@ErrMsg= CASE WHEN t.IsCredit=1 AND e.CreditGroupID IS NOT NULL THEN 'The Credit Currency ' 
						  WHEN t.IsCredit=0 AND e.LicenseeGroupID IS NOT NULL THEN 'The Deposit Currency ' END
						+ e.currency + ' exists in another group.'
		FROM #tmpExchange t
		INNER JOIN exchange e WITH (NOLOCK) ON e.ExchangeId=t.ExchangeID
		WHERE (t.IsCredit=1 AND e.CreditGroupID IS NOT NULL)
			OR (t.IsCredit=0 AND e.LicenseeGroupID IS NOT NULL)
		
		IF @ErrCode<>0 RETURN
	END
	ELSE 
	BEGIN
		--CREDIT
		SELECT TOP 1
			@ErrCode=106,
			@ErrMsg= 'The Credit Currency ' + ee.currency + ' exists in another group.'
		FROM #tmpExchange t
		INNER JOIN exchange ee WITH (NOLOCK)
				ON t.ExchangeID=ee.ExchangeId
		LEFT JOIN exchange e WITH (NOLOCK)
				ON t.ExchangeID=e.ExchangeId
				AND e.CreditGroupID=t.CurrencyGroupID 
		WHERE t.IsCredit=1 AND e.ExchangeId IS NULL AND ee.CreditGroupID IS NOT NULL

		IF @ErrCode<>0 RETURN
		
		--DEPOSIT
		SELECT TOP 1
			@ErrCode=107,
			@ErrMsg= 'The Deposit Currency ' + ee.currency + ' exists in another group.'
		FROM #tmpExchange t
		INNER JOIN exchange ee WITH (NOLOCK)
				ON t.ExchangeID=ee.ExchangeId
		LEFT JOIN exchange e WITH (NOLOCK)
				ON t.ExchangeID=e.ExchangeId
				AND e.LicenseeGroupID=t.CurrencyGroupID 
		WHERE t.IsCredit=0 AND e.ExchangeId IS NULL AND ee.LicenseeGroupID IS NOT NULL

		IF @ErrCode<>0 RETURN
	END

	--currency by offersite
	SELECT TOP 1
		@ErrCode=104,
		@ErrMsg= CASE WHEN t.IsCredit=1 AND e.OfferSite=2 THEN 'The Deposit Currency ' 
					  WHEN t.IsCredit=0 AND e.OfferSite=1 THEN 'The Credit Currency ' END
				+ e.currency
				+ ' cannot be assigned to '
				+ CASE WHEN t.IsCredit=1 THEN 'Credit Currency Group.' 
					   WHEN t.IsCredit=0 THEN 'Deposit Currency Group.' END
	FROM #tmpExchange t
	INNER JOIN exchange e WITH (NOLOCK) ON e.ExchangeId=t.ExchangeID
	WHERE (t.IsCredit=1 AND e.OfferSite=2)
		OR (t.IsCredit=0 AND e.OfferSite=1)

	IF @ErrCode<>0 RETURN

	--Not Exist currency group
	SELECT TOP 1
		@ErrCode=108,
		@ErrMsg= CASE WHEN t.IsCredit=1 THEN 'The Credit Currency Group ID ' 
					  WHEN t.IsCredit=0 THEN 'The Deposit Currency Group ID ' END
				+ CAST(t.CurrencyGroupID AS VARCHAR(5))
				+ ' does not exists.'
	FROM #tmpExchange t
	WHERE @IsUpdate=1 
	AND ((t.IsCredit=1 AND t.CurrencyGroupID NOT IN (SELECT CreditGroupID FROM exchange e WITH (NOLOCK) WHERE e.CreditGroupID IS NOT NULL))
		OR (t.IsCredit=0 AND t.CurrencyGroupID NOT IN (SELECT LicenseeGroupID FROM exchange e WITH (NOLOCK) WHERE e.LicenseeGroupID IS NOT NULL)))
	
	IF @ErrCode<>0 RETURN 

	--currency: be assigned to more than one group
	;WITH tmpCurrency AS (
		SELECT e.currency, t.IsCredit
		FROM #tmpExchange t
		INNER JOIN exchange e WITH (NOLOCK) ON e.ExchangeId=t.ExchangeID
		GROUP BY e.currency, t.IsCredit
		HAVING COUNT(1)>1
	)
	SELECT TOP 1
		@ErrCode=110,
		@ErrMsg= CASE WHEN IsCredit=1 THEN 'The Credit Currency ' 
					  WHEN IsCredit=0 THEN 'The Deposit Currency ' END
				+ currency
				+ ' cannot be assigned to more than one group.'
	FROM tmpCurrency

	IF @ErrCode<>0 RETURN 

END
GO