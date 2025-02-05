/*<info serverAlias="DBGLOB-GlobCustDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_GlobalStakeLevelGroup_Ins] 
	-- Add the parameters for the stored procedure here
	 @InputData	VARCHAR(MAX)	= ''
	,@UserID	INT
	,@IP		VARCHAR(50)		= ''
	,@ErrCode	INT = 0				OUTPUT
	,@ErrMsg	NVARCHAR(4000)	= '' OUTPUT
AS
/*
	Created: 20240625@Tacy
	Task: NAP CM - Non-sports Company Bet Limit Setting
	DB: DBGLOB-GlobCustDB

	Revisions:
		- 20240625@Tacy: Initalize SP [RedmineID: #196256]
		- 20250205@Tacy: Move to GlobCustDB [RedmineID: #216870]

	Param's Explanation:
		@InputData = <ROOT>
							<BetLimit 
											SportType="248" 
											CreditGroupID= "1"
											LicenseeGroupID= "3"
											SiteID="0"
											GameGroupID="1"                --//Slot game
											NewMinBet="0.01" 
											NewMaxBet="401" 
											NewRemark="Buybonus Feature x50"
											CurMinBet="0.01" 
											CurMaxBet="400" 
											CurRemark="Buybonus Feature x50"
							/>
							<BetLimit 
											SportType="248" 
											CreditGroupID= "1"
											LicenseeGroupID= "3"
											SiteID="0"
											GameGroupID="2"                --//Others
											NewMinBet="0.01" 
											NewMaxBet="401" 
											NewRemark="Buybonus Feature x50"
											CurMinBet="0.01" 
											CurMaxBet="400" 
											CurRemark="Buybonus Feature x50"
							/>
					</ROOT>
*/
BEGIN
	SET NOCOUNT ON;
	
	IF ISNULL(@InputData,'')=''	RETURN

	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @logSpData NVARCHAR(MAX)

	DECLARE @InputTbl TABLE (
			  SportType			SMALLINT
			, CreditGroupID		TINYINT
			, LicenseeGroupID	TINYINT
			, SiteID			INT DEFAULT (0)
			, GameGroupID		TINYINT
			, NewMinBet			MONEY
			, NewMaxBet			MONEY
			, NewRemark			VARCHAR(1000)
			, CurMinBet			MONEY
			, CurMaxBet			MONEY
			, CurRemark			VARCHAR(1000)
	)

	CREATE TABLE #BetLimitTbl (
			  SportType			SMALLINT
			, CurrencyGroupID	TINYINT
			, SiteID			INT DEFAULT (0)
			, GameGroupID		TINYINT
			, NewMinBet			MONEY
			, NewMaxBet			MONEY
			, NewRemark			VARCHAR(1000)
			, CurMinBet			MONEY
			, CurMaxBet			MONEY
			, CurRemark			VARCHAR(1000)
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

		INSERT INTO @InputTbl(SportType, CreditGroupID, LicenseeGroupID, SiteID, GameGroupID, 
							  NewMinBet, NewMaxBet, NewRemark,
							  CurMinBet, CurMaxBet, CurRemark)
		SELECT	SportType, CreditGroupID, LicenseeGroupID, SiteID, GameGroupID, 
				NewMinBet, NewMaxBet, NewRemark,
				CurMinBet, CurMaxBet, CurRemark
		FROM OPENXML(@iDoc, '/ROOT/BetLimit', 1) WITH (
				SportType			SMALLINT
				, CreditGroupID		TINYINT
				, LicenseeGroupID	TINYINT
				, SiteID			INT 
				, GameGroupID		TINYINT
				, NewMinBet			MONEY
				, NewMaxBet			MONEY
				, NewRemark			VARCHAR(1000)
				, CurMinBet			MONEY
				, CurMaxBet			MONEY
				, CurRemark			VARCHAR(1000)
		)
		EXEC sp_xml_removedocument @iDoc
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE();		
		RETURN
	END CATCH

	INSERT INTO #BetLimitTbl (SportType, CurrencyGroupID, GameGroupID, SiteID,
							 NewMinBet, NewMaxBet, NewRemark,
							 CurMinBet, CurMaxBet, CurRemark,
							 IsCredit)
	SELECT
			SportType
			,i.CreditGroupID
			,i.GameGroupID
			,i.SiteID
			,i.NewMinBet, i.NewMaxBet, i.NewRemark
			,i.CurMinBet, i.CurMaxBet, i.CurRemark
			,1 AS IsCredit
	FROM @InputTbl i
	WHERE i.CreditGroupID<>0
	UNION ALL
	SELECT
			SportType
			,i.LicenseeGroupID
			,i.GameGroupID
			,i.SiteID
			,i.NewMinBet, i.NewMaxBet, i.NewRemark
			,i.CurMinBet, i.CurMaxBet, i.CurRemark
			,0 AS IsCredit
	FROM @InputTbl i
	WHERE i.LicenseeGroupID<>0

	BEGIN TRY
		--CREDIT
		IF EXISTS (SELECT TOP 1 1 FROM #BetLimitTbl WHERE IsCredit=1)
		BEGIN
			--DELETE: unchange
			DELETE T
			FROM #BetLimitTbl t
			INNER JOIN ProductStakeLevelGroup s WITH (NOLOCK)
					ON t.SportType=s.SportType
					AND t.CurrencyGroupID=s.CreditGroupID
					AND t.GameGroupID=s.GameGroupID
			WHERE t.IsCredit=1 AND s.isDeleted=0
				AND s.MinBet=t.NewMinBet
				AND s.MaxBet=t.NewMaxBet
				AND ISNULL(s.Remark,'')=ISNULL(t.NewRemark,'')
			
			--Update setting
			UPDATE s
			SET s.MinBet=t.NewMinBet
				,s.MaxBet=t.NewMaxBet
				,s.Remark=t.NewRemark
				,s.[RepUpdateTime]=dbo.f_GetDateTime2()
				,s.isDeleted=0	--case: isDeleted=1, user insert new setting.
			FROM ProductStakeLevelGroup s WITH (ROWLOCK,UPDLOCK)
			INNER JOIN #BetLimitTbl t 
				ON t.SportType=s.SportType
				AND t.CurrencyGroupID=s.CreditGroupID
				AND t.GameGroupID=s.GameGroupID
			WHERE t.IsCredit=1

			DELETE T
			FROM #BetLimitTbl t
			INNER JOIN ProductStakeLevelGroup s WITH (NOLOCK)
					ON t.SportType=s.SportType
					AND t.CurrencyGroupID=s.CreditGroupID
					AND t.GameGroupID=s.GameGroupID
			WHERE t.IsCredit=1

			--Insert new settings:
			INSERT INTO ProductStakeLevelGroup (Sporttype, GameGroupID, CreditGroupID, MinBet, MaxBet, Remark, RepUpdateTime)
			SELECT t.Sporttype, t.GameGroupID, t.CurrencyGroupID, t.NewMinBet, t.NewMaxBet, t.NewRemark, dbo.f_GetDateTime2()
			FROM #BetLimitTbl t
			WHERE t.IsCredit=1
		END

		--DEPOSIT
		IF EXISTS (SELECT TOP 1 1 FROM #BetLimitTbl WHERE IsCredit=0)
		BEGIN
			--DELETE: unchange
			DELETE T
			FROM #BetLimitTbl t 
			INNER JOIN Dep_ProductStakeLevelGroup s  WITH (NOLOCK)
					ON t.SportType=s.SportType
					AND t.CurrencyGroupID=s.LicenseeGroupID
					AND t.GameGroupID=s.GameGroupID
					AND t.SiteID=s.SiteID
			WHERE t.IsCredit=0 AND s.isDeleted=0
				AND s.MinBet=t.NewMinBet
				AND s.MaxBet=t.NewMaxBet
				AND ISNULL(s.Remark,'')=ISNULL(t.NewRemark,'')

			--Update new settings:
			UPDATE s
			SET s.MinBet=t.NewMinBet
				,s.MaxBet=t.NewMaxBet
				,s.Remark=t.NewRemark
				,s.[RepUpdateTime]=dbo.f_GetDateTime2()
				,s.isDeleted=0	--case: isDeleted=1, user insert new setting.
			FROM Dep_ProductStakeLevelGroup s  WITH (ROWLOCK,UPDLOCK)
			INNER JOIN #BetLimitTbl t 
					ON t.SportType=s.SportType
					AND t.CurrencyGroupID=s.LicenseeGroupID
					AND t.GameGroupID=s.GameGroupID
					AND t.SiteID=s.SiteID
			WHERE t.IsCredit=0

			DELETE T
			FROM #BetLimitTbl t 
			INNER JOIN Dep_ProductStakeLevelGroup s  WITH (NOLOCK)
					ON t.SportType=s.SportType
					AND t.CurrencyGroupID=s.LicenseeGroupID
					AND t.GameGroupID=s.GameGroupID
					AND t.SiteID=s.SiteID
			WHERE t.IsCredit=0

			--Insert new settings:
			INSERT INTO Dep_ProductStakeLevelGroup (Sporttype, GameGroupID, LicenseeGroupID, SiteID, MinBet, MaxBet, Remark, RepUpdateTime)
			SELECT t.Sporttype, t.GameGroupID, t.CurrencyGroupID, t.SiteID, t.NewMinBet, t.NewMaxBet, t.NewRemark, dbo.f_GetDateTime2()
			FROM #BetLimitTbl t 
			WHERE t.IsCredit=0
		END
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
	
	--Write log
	SELECT @EndRun	= GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)
	
	DECLARE @NewLog VARCHAR(MAX)

	SET @NewLog = '<NAP_GlobalStakeLevelGroup_Ins IP="'+ COALESCE(CAST(@IP AS VARCHAR(15)),SPACE(1))+'" >'
	SELECT @logSpData = REPLACE(REPLACE(@InputData, '<ROOT>', @NewLog),'/ROOT','/NAP_GlobalStakeLevelGroup_Ins')
	
	EXEC  Acc_WriteLog_UserLog_RunSP_Wrapper
				@UserID = @UserID,
				@ActionID = 31770,
				@TrackingValue = @LogSPData,
				@duration = @Duration
END						
GO
