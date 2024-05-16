/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_PayoutPromotion_Upd]     
     @CustIDList	NVARCHAR(MAX)
	,@Status		TINYINT
	,@TypeID		TINYINT
	,@VerificationCode	VARCHAR(50)=NULL
	,@PaymentDate	DATE=NULL
	,@Remark	NVARCHAR(1000)=NULL
	,@IP		NVARCHAR(15)
	,@userid	INT
	,@Errcode	INT = 0 OUTPUT
	,@ErrMsg	NVARCHAR(MAX) = '' OUTPUT
AS    
    
/*    
    Created by: Tacy@20240328
    Task : Update Payout Promotion Status
    DB: DBTXN/bodb02    
    
	Revisions:
        - 20240328@Tacy: NAP CM - Correct Score Promotion [redmine: #202974]
		- 20240514@Tacy: remove teamname [redmine: #205071]
		
	Param's Explanation:
		* @CustIDList = <Root>
							<Promotion DrawID="1" CustID="23003140"/>
							<Promotion DrawID="2" CustID="20650722"/>
							<Promotion DrawID="3" CustID="17241027"/>
						</Root>
		
		* @Status : 0 ~ Open
					1 ~ Verified
					2 ~ Completed
					3 ~ Cancelled
	
		* @VerificationCode : if update Satus <> 'Verified' --> @VerificationCode=''

		* @PaymentDate : if update Satus <> 'Completed' --> @PaymentDate=''
*/    
BEGIN    
    SET NOCOUNT ON ;

	DECLARE  @startRun DATETIME
			,@duration INT
	
	DECLARE  @CustID	INT
			,@DrawID	INT
			,@oldStatus	TINYINT
			,@oldPaymentDate DATE
			,@oldRemark	NVARCHAR(1000)
			,@oldValue VARCHAR(MAX)
			,@newValue VARCHAR(MAX)
	
	SET @startRun = GETDATE()
	
	IF (@Status<>1 AND @VerificationCode IS NOT NULL)
		OR (@Status<>2 AND @PaymentDate IS NOT NULL)
		OR (@Status=1 AND @VerificationCode IS NULL AND @Remark IS NULL)
	BEGIN
		SELECT @Errcode = 99
			, @ErrMsg='Input wrong value'
		RETURN
	END

	DECLARE @tblDrawList TABLE (
		 DrawID		INT PRIMARY KEY
		,CustID		INT 
		,IsFinished BIT DEFAULT(0)
	)

	--Parse XML data
	DECLARE @iDoc INT

	EXEC sp_xml_preparedocument @iDoc OUTPUT
		, @CustIDList

	--Parse LIST CustID
	INSERT INTO @tblDrawList (DrawID, CustID)
	SELECT  DrawID, CustID
	FROM OPENXML(@iDoc, '/Root/Promotion', 1) WITH (
				 DrawID	INT
				,CustID	INT
			)

	EXEC sp_xml_removedocument @iDoc

	--Invalid verification code
	IF @Status=1 AND @VerificationCode IS NOT NULL AND
	NOT EXISTS (SELECT 1 FROM LuckyDrawList ld WITH (NOLOCK)
				INNER JOIN @tblDrawList t ON t.DrawID=ld.DrawID
				WHERE ld.VerificationCode=@VerificationCode 
				AND ld.TypeID=@TypeID
				AND IsDeleted=0)  --Verified
	BEGIN
		SELECT @Errcode=100
			, @ErrMsg='Invalid code'

		RETURN
	END

	IF @Status=2 AND 
		EXISTS (SELECT TOP 1 1 FROM LuckyDrawList ld WITH (NOLOCK) 
				INNER JOIN @tblDrawList t ON t.DrawID=ld.DrawID
				WHERE CAST(CreatedDate AS DATE)>@PaymentDate
				AND IsDeleted=0)
	BEGIN
		SELECT @Errcode=101
			, @ErrMsg='Invalid Payment Date'

		RETURN
	END

	--This DrawID is not available
	SELECT TOP 1 
			@ErrCode=102
			,@ErrMsg='The draw - ' + CAST(t.DrawID AS varchar) + ' is not available.'
	FROM @tblDrawList t
	OUTER APPLY (SELECT ld.DrawID FROM LuckyDrawList ld WITH (NOLOCK) 
				 WHERE ld.DrawID=t.DrawID AND ld.isDeleted=0
					AND ld.IsLicensee=0) l
	WHERE l.DrawID IS NULL

	IF @Errcode=102 RETURN

	DECLARE @TempErrMsg NVARCHAR(1000)
	DECLARE @TempErrCode INT
	
	SET @ErrMsg = '<ROOT>';

	WHILE EXISTS (SELECT TOP 1 1 FROM @tblDrawList WHERE IsFinished=0)
	BEGIN
		GetCustId:
			UPDATE TOP (1) T
			SET	t.IsFinished=1
				,@DrawID = DrawID
				,@CustID = CustID
			FROM @tblDrawList t
			WHERE IsFinished=0

		SELECT @Errcode = NULL, @ErrMsg = NULL

		SELECT @oldStatus=StatusID
			, @oldPaymentDate=SettledDate
			, @oldRemark=Remark
		FROM LuckyDrawList WITH (NOLOCK)
		WHERE DrawID = @DrawID AND IsDeleted=0
		
		BEGIN TRY
			UPDATE ld
			SET ld.StatusID=@Status
				,ld.SettledDate=ISNULL(@PaymentDate, @oldPaymentDate)
				,ld.Remark=ISNULL(@Remark, @oldRemark)
				,LastModifiedDate=GETDATE()
				,LastModifiedUserID=@userid
				,RepUpdateTime=SYSDATETIME()
			FROM LuckyDrawList ld WITH (ROWLOCK, UPDLOCK)
			WHERE DrawID=@DrawID AND IsDeleted=0
		END TRY
		BEGIN CATCH
			SELECT @TempErrMsg = ERROR_MESSAGE()
				,@TempErrCode = ERROR_NUMBER()

			SET @Errcode = 999
			SET @ErrMsg += '<Error CustID="' + CAST(@CustID AS VARCHAR(30))
						+ '" ErrCode="' + CAST(ISNULL(@TempErrCode,'0') AS VARCHAR(5))
						+ '" ErrMsg="' + ISNULL(@TempErrMsg,'') + '" />'
		END CATCH
	
		--Write log
		SELECT @oldValue = '<NAP_PayoutPromotion_Upd DrawID="' + CAST(@DrawID AS varchar) 
						+ '" Status ="' + COALESCE(CAST(@oldStatus AS varchar), SPACE(1)) 
						+ '" PaymentDate ="' + COALESCE(CAST(@oldPaymentDate AS varchar), SPACE(1)) 
						+ '" Remark ="' + COALESCE(@oldRemark, SPACE(1)) 
						+ '" IP="' + COALESCE(@IP, SPACE(1))
						+ '" />'

		SELECT @newValue = '<NAP_PayoutPromotion_Upd DrawID="' + CAST(@DrawID AS varchar)   
						+ '" Status ="' + COALESCE(CAST(@Status AS varchar), SPACE(1)) 
						+ '" PaymentDate ="' + COALESCE(CAST(ISNULL(@PaymentDate, @oldPaymentDate) AS varchar), SPACE(1)) 
						+ '" Remark ="' + COALESCE(ISNULL(@Remark, @oldRemark), SPACE(1)) 
						+ '" IP="' + COALESCE(@IP, SPACE(1))
						+ '" />'
		
		SET @duration = DATEDIFF(MILLISECOND, @startRun, GETDATE())

		BEGIN TRY
			DECLARE @tempNewValue NVARCHAR(MAX)
				,@tempOldValue NVARCHAR(MAX)

			SELECT @tempNewValue = @newValue + '" ErrCode="' + COALESCE(CAST(@TempErrCode AS VARCHAR(50)), space(1)) + '" ErrMsg="' + COALESCE(@TempErrMsg, space(1)) + '" />'
				,@tempOldValue = @oldValue + '" ErrCode="' + COALESCE(CAST(@TempErrCode AS VARCHAR(50)), space(1)) + '" ErrMsg="' + COALESCE(@TempErrMsg, space(1)) + '" />'

			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP @UserID = @userid
				,@CustID = @CustId
				,@ActionID = 31776
				,@TrackingValue = @tempNewValue
				,@TrackingValue2 = @tempOldValue
				,@duration = @duration
		END TRY

		BEGIN CATCH
			SELECT @oldValue = @oldValue + '" ErrMsg="' + ERROR_MESSAGE() + '" />'

			SELECT @newValue = @newValue + '" ErrMsg="' + ERROR_MESSAGE() + '" />'

			EXEC DBCUST.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP @UserID = @userid
				,@CustID = @CustID
				,@ActionID = 31776
				,@TrackingValue = @newValue
				,@TrackingValue2 = @oldValue
				,@duration = @duration
		END CATCH
	END
	 
	SET @ErrMsg += '</ROOT>'
END
GO