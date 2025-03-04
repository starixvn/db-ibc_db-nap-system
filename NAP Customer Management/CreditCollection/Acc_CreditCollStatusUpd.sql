/*<info serverAlias="DBCust-CustDB" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CreditCollStatusUpd] 
	@CustId 			INT,
	@Status 			INT = 0,
	@UserId 			INT,
	@IP					VARCHAR(15)='',
	@Language			VARCHAR(2) = 'E',
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(200) = '' OUTPUT
AS
/*
	Created: Louis
	Date: 2018-11-05
	Task: Credit Collection Summary
	DB: DBCust/CustDB

	Revisions:
		--20181105@Louis: Credit Collection Summary  [RedmineID: #98621]
		- 20250102@Hughie: Scale Out DBCUST - Apply Inhouse replication for the remaning tables [Redmine: #215627]
	Parameter's explaination: 		
		• @Status: 			 0: Normal
							 1: Alert							  
							 2: Unused
*/
BEGIN
	SET NOCOUNT ON	 
	DECLARE @startRun DATETIME;
	DECLARE @endRun DATETIME;
	DECLARE @duration INT;
	SET @startRun = GETDATE();
		
	DECLARE @OldStatus INT;
	
	SELECT @OldStatus = Coll_Status
	FROM CustDirectAccount WITH(NOLOCK)
	WHERE CustId = @CustId;		
	
	IF @Status = @OldStatus 
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Status Unchanged'				
		RETURN
	END		
	
	UPDATE CustDirectAccount WITH(ROWLOCK, UPDLOCK)
	SET Coll_Status = @Status
		,RepUpdateTime = dbo.f_GetDateTime2()
	WHERE CustId = @CustId;
	
	SET @ErrMsg = '';
				
	IF (@@ERROR <> 0)
	BEGIN
		SELECT @ErrCode = 101, 
			@ErrMsg =
				CASE @Language 
				WHEN 'E' THEN 'Update process is unsuccessful !'
				ELSE [dbo].[f_Get_MsgNamebyMsgID](90001, @Language)
				END
		RETURN
	END
	
	
	DECLARE @LogData NVARCHAR(4000);
	SELECT @LogData = '<Acc_CreditCollStatusUpd ' 
					+ 'CustId="' + COALESCE(CAST(@CustId AS VARCHAR(50)), SPACE(1)) + '" ' 
					+ 'Coll_Status="'+ COALESCE([dbo].[f_CreditColl_GetStatusName](@Status), SPACE(1)) + '" '
					+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
					+ 'ErrCode="' + COALESCE(CAST(@ErrCode AS VARCHAR(10)),SPACE(1)) + '" '
					+ 'ErrMsg="' + @ErrMsg + '" '
					+ '/>';

	DECLARE @LogOldData NVARCHAR(4000);
	SELECT @LogOldData = '<Acc_CreditCollStatusUpd ' 
					+ 'CustId="' + COALESCE(CAST(@CustId AS VARCHAR(50)), SPACE(1)) + '" ' 
					+ 'Coll_Status="'+ COALESCE([dbo].[f_CreditColl_GetStatusName](@OldStatus), SPACE(1)) + '" '
					+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
					+ 'ErrCode="' + COALESCE(CAST(@ErrCode AS VARCHAR(10)),SPACE(1)) + '" '
					+ 'ErrMsg="' + @ErrMsg + '" '
					+ '/>';
	
	SET @endRun = GETDATE();
	set @duration  = DATEDIFF(MILLISECOND, @startRun, @endRun);

	EXEC Acc_WriteLog_UserLog_RunSP_Wrapper @Userid = @UserId
		, @CustId = @CustId
		, @ActionID = 1168
		, @TrackingValue = @LogData
		, @TrackingValue2 = @LogOldData
		, @Duration = @duration;	
		
END

GO




