/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE NAP_ProblemAccount_LicenseeAcknowledgementUpd
	@LicenseeID INT,
	@IsAcknowledgement BIT,
	@UserID 	INT,
	@IP			VARCHAR(15) = '',	
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(4000) = '' OUTPUT
AS
	/*
		Created: 20200211@Johnson
		Task: Problem Account - Manage Licensee Acknowledgement
		DB: DBCUST/bodb_Licensee
		
		Revisions:
			- 20200211@Johnson: initial sp [redmine:#128077]
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartRun DATETIME, @Duration INT
	DECLARE @IsAcknowledgement_Old BIT,
			@Licensee VARCHAR(30)
	
	SELECT @IsAcknowledgement_Old = ISNULL(IsAcknowledgement,0),
		@Licensee = LicenseeName
	FROM Licensee WITH(NOLOCK)
	WHERE LicenseeID = @LicenseeID
	
	IF @@Rowcount = 0
	BEGIN
		SELECT @ErrCode = 100,
			@ErrMsg = 'Invalid Licensee!'
		RETURN
	END
	
	IF @IsAcknowledgement = @IsAcknowledgement_Old
		RETURN
		
	UPDATE Licensee WITH(UPDLOCK,ROWLOCK)
	SET IsAcknowledgement = @IsAcknowledgement
	WHERE LicenseeID = @LicenseeID
	
	IF @@ERROR > 0
	BEGIN
		SELECT @ErrCode = 101,
			@ErrMsg = 'Update unsuccessfully.'
		RETURN
	END
	
	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

	-- Write log
	DECLARE @LogData VARCHAR(500),
			@LogData_Old VARCHAR(500)
	SELECT  @LogData = '<R'
							+ ' Licensee="' + @Licensee + '"'								
							+ ' IsAcknowledgement="' + COALESCE(CAST(@IsAcknowledgement AS VARCHAR(10)), SPACE(1)) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'	
							
	SELECT  @LogData_old = '<R'
							+ ' Licensee="' + @Licensee + '"'								
							+ ' IsAcknowledgement="' + COALESCE(CAST(@IsAcknowledgement_old AS VARCHAR(10)), SPACE(1)) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'
	
	EXEC dbo.Lrf_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustID				= @LicenseeID,		
			@ActionId			= 31624,
			@TrackingValue		= @LogData,
			@TrackingValue2		= @LogData_Old,
			@Duration			= @Duration
END
	
