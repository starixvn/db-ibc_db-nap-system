/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_GlobalStakeGroup_Del] 
	-- Add the parameters for the stored procedure here
	 @InputData	VARCHAR(MAX)	= ''
	,@IsCredit	BIT				= 0
	,@UserID	INT
	,@IP		VARCHAR(50)		= ''
	,@ErrCode	INT = 0				OUTPUT
	,@ErrMsg	NVARCHAR(4000)	= '' OUTPUT
AS
/*
	Created: 20240625@Tacy
	Task: NAP CM - Non-sports Company Bet Limit Setting
	DB: DBCUST/CustDB

	Revisions:
		- 20240625@Tacy: Initalize SP [RedmineID: #196256]
		
	Param's Explanation:
		@InputData = '<ROOT>
							<BetLimit 
											SportType="248" 
											CurrencyGroupID= "1"
											SiteID="0"
											GameGroupID="1"                --//Slot game
							/>
							<BetLimit 
											SportType="248" 
											CurrencyGroupID= "1"
											SiteID="0"
											GameGroupID="2"                --//Others
							/>
					</ROOT>'
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @logSpData NVARCHAR(MAX)
	
	CREATE TABLE #BetLimitTbl (
			  SportType			SMALLINT
			, CurrencyGroupID	TINYINT
			, SiteID			INT DEFAULT (0)
			, GameGroupID		TINYINT
			, IsCredit			BIT DEFAULT(0)
	)
	
	IF @InputData IS NULL OR @InputData = ''
		RETURN
		
	SELECT	@ErrCode = 0, @ErrMsg = '' 
	
	SET @StartRun = GETDATE()	

	--Parse XML data
	DECLARE @iDoc INT
	BEGIN TRY
		EXEC sp_xml_preparedocument @iDoc OUTPUT
			, @InputData

		INSERT INTO #BetLimitTbl(SportType, CurrencyGroupID, SiteID, GameGroupID, IsCredit)
		SELECT	SportType, CurrencyGroupID, SiteID, GameGroupID, @IsCredit
		FROM OPENXML(@iDoc, '/ROOT/BetLimit', 1) WITH (
				SportType			SMALLINT
				, CurrencyGroupID	TINYINT
				, SiteID			INT 
				, GameGroupID		TINYINT
		)
		EXEC sp_xml_removedocument @iDoc
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE();		
		RETURN
	END CATCH

	--check: not exists setting
	IF EXISTS (SELECT TOP 1 1 FROM #BetLimitTbl t
				INNER JOIN ProductStakeLevelGroup s WITH (NOLOCK)
							 ON t.SportType=s.SportType
							 AND t.CurrencyGroupID=s.CreditGroupID
							 AND t.GameGroupID=s.GameGroupID
				WHERE IsCredit=1)
	BEGIN
		SELECT TOP 1 
				@ErrCode=100
				,@ErrMsg='The Sport Type ' + CAST (t.SportType AS varchar) 
						+ ' - Credit Group ID ' + CAST (t.CurrencyGroupID AS varchar) 
						+ ' - Game Group ID ' + CAST (t.GameGroupID AS varchar) 
						+ ' is not available.'
		FROM #BetLimitTbl t
		INNER JOIN ProductStakeLevelGroup s WITH (NOLOCK)
							 ON t.SportType=s.SportType
							 AND t.CurrencyGroupID=s.CreditGroupID
							 AND t.GameGroupID=s.GameGroupID
		WHERE IsCredit=1

		RETURN
	END

	IF EXISTS (SELECT TOP 1 1 FROM #BetLimitTbl t
				INNER JOIN Dep_ProductStakeLevelGroup s WITH (NOLOCK)
							 ON t.SportType=s.SportType
							 AND t.CurrencyGroupID=s.LicenseeGroupID
							 AND t.GameGroupID=s.GameGroupID 
							 AND t.SiteID=s.SiteID
				WHERE IsCredit=0)
	BEGIN
		SELECT TOP 1 
				@ErrCode=101
				,@ErrMsg='The Sport Type ' + CAST (t.SportType AS varchar) 
						+ ' - Licensee Group ID ' + CAST (t.CurrencyGroupID AS varchar) 
						+ ' - Game Group ID ' + CAST (t.GameGroupID AS varchar) 
						+ ' - Site ID ' + CAST (t.SiteID AS varchar) 
						+ ' is not available.'
		FROM #BetLimitTbl t
		INNER JOIN Dep_ProductStakeLevelGroup s WITH (NOLOCK)
							 ON t.SportType=s.SportType
							 AND t.CurrencyGroupID=s.LicenseeGroupID
							 AND t.GameGroupID=s.GameGroupID 
							 AND t.SiteID=s.SiteID
		WHERE IsCredit=0

		RETURN
	END

	--DELETE:
	BEGIN TRY
		--CREDIT
		IF EXISTS (SELECT TOP 1 1 FROM #BetLimitTbl WHERE IsCredit=1)
		BEGIN
			DELETE s
			OUTPUT deleted.Sporttype, deleted.CreditGroupID, deleted.GameGroupID
				INTO ProductStakeLevelGroup_Del_Inhouse (Sporttype, CreditGroupID, GameGroupID)
			FROM ProductStakeLevelGroup s  WITH (ROWLOCK)
			INNER JOIN #BetLimitTbl t 
					ON t.SportType=s.SportType
					AND t.CurrencyGroupID=s.CreditGroupID
					AND t.GameGroupID=s.GameGroupID
			WHERE IsCredit=1
		END

		--DEPOSIT
		IF EXISTS (SELECT TOP 1 1 FROM #BetLimitTbl WHERE IsCredit=0)
		BEGIN
			DELETE s
			OUTPUT deleted.Sporttype, deleted.LicenseeGroupID, deleted.GameGroupID, deleted.SiteID
				INTO Dep_ProductStakeLevelGroup_Del_Inhouse (Sporttype, LicenseeGroupID, GameGroupID, SiteID)
			FROM Dep_ProductStakeLevelGroup s  WITH (ROWLOCK)
			INNER JOIN #BetLimitTbl t 
					ON t.SportType=s.SportType
					AND t.CurrencyGroupID=s.LicenseeGroupID
					AND t.GameGroupID=s.GameGroupID
					AND t.SiteID=s.SiteID
			WHERE IsCredit=0
		END
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
	
	--Write log
	SELECT @EndRun	= GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

	DECLARE @NewLog VARCHAR(MAX)

	SET @NewLog = '<NAP_GlobalStakeGroup_Del IP="' + COALESCE(CAST(@IP AS VARCHAR(15)),SPACE(1)) +'" >'
	SELECT @logSpData = REPLACE(REPLACE(@InputData, '<ROOT>', @NewLog),'/ROOT','/NAP_GlobalStakeGroup_Del')

	EXEC  Acc_WriteLog_UserLog_RunSP_Wrapper
				@UserID = @UserID,
				@ActionID = 31771,
				@TrackingValue = @LogSPData,
				@duration = @Duration
END						
GO