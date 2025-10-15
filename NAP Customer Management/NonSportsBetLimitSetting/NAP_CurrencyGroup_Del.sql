/*<info serverAlias="DBCUST-CustDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_CurrencyGroup_Del] 
	-- Add the parameters for the stored procedure here
	 @IsCredit BIT=1 -- 1 : Credit, 0 :Deposit
	,@CurrencyGroupID TINYINT
	,@UserID	INT
	,@IP		VARCHAR(50)		= ''
	,@ErrCode	INT = 0				OUTPUT
	,@ErrMsg	NVARCHAR(4000)	= '' OUTPUT
AS
/*
	Created: 20230914@Tacy
	Task : Nap CM - Non-sport Company Bet Limit Setting - Manage Currency Group
	DB: DBCUST-CustDB

	Revisions:
		- 20230914@Tacy: Create SP [Redmine: #196256]
		
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @StartRun DATETIME, @Duration INT
		, @logSpData NVARCHAR(MAX)
	
	SET @StartRun = GETDATE()	

	IF (NOT EXISTS (SELECT 1 FROM exchange WITH (NOLOCK)
					WHERE CreditGroupID=@CurrencyGroupID)
		AND @IsCredit=1)
	OR (NOT EXISTS (SELECT 1 FROM exchange WITH (NOLOCK)
					WHERE LicenseeGroupID=@CurrencyGroupID)
		AND @IsCredit=0)
	BEGIN
		SELECT @ErrCode=100
			, @ErrMsg=CASE WHEN @IsCredit = 1 THEN 'The Credit' ELSE 'The Deposit' END
					+ ' Currency Group '
					+ CAST(@CurrencyGroupID AS VARCHAR(5)) + ' does not exist.'

		RETURN
	END

	--Log
	SELECT  @logSpData = (SELECT @CurrencyGroupID AS CurrencyGroupID
								, (SELECT STUFF((SELECT ',' + CAST(ExchangeId AS VARCHAR(5))
												FROM exchange e WITH (NOLOCK)
												WHERE  (@IsCredit=1 AND CreditGroupID=@CurrencyGroupID)
													OR (@IsCredit=0 AND LicenseeGroupID=@CurrencyGroupID)
												FOR XML PATH('')),1,1,''))
									AS ExchangeIDs
								, @IsCredit AS IsCredit
							FOR XML RAW ('CurrencyGroup'), ROOT('ROOT'))

	BEGIN TRY
		IF @IsCredit=1
		BEGIN
			UPDATE exchange WITH (ROWLOCK, UPDLOCK)
			SET CreditGroupID=NULL
				,RepUpdateTime=SYSDATETIME()
			WHERE CreditGroupID=@CurrencyGroupID
		END
		ELSE 
		BEGIN
			UPDATE exchange WITH (ROWLOCK, UPDLOCK)
			SET LicenseeGroupID=NULL
				,RepUpdateTime=SYSDATETIME()
			WHERE LicenseeGroupID=@CurrencyGroupID
		END
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE();		
		RETURN
	END CATCH

	--Write log
	SELECT	@duration = DATEDIFF(MILLISECOND, @startRun, GETDATE())

	DECLARE @NewLog VARCHAR(MAX)

	SET @NewLog = '<NAP_CurrencyGroup_Del IP="'+ COALESCE(CAST(@IP AS VARCHAR(15)),SPACE(1))+'" >'
	SELECT @logSpData = REPLACE(REPLACE(@logSpData, '<ROOT>', @NewLog),'/ROOT','/NAP_CurrencyGroup_Del')

	EXEC  Acc_WriteLog_UserLog_RunSP_Wrapper
				@UserID = @UserID,
				@ActionID = 31779,
				@TrackingValue = @LogSPData,
				@duration = @Duration
END
GO