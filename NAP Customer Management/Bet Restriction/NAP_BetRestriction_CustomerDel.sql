/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CustomerDel] 
	  @CustID		INT
	 ,@UserId		INT
	 ,@IP			VARCHAR(15) = ''
	 ,@SportType    SMALLINT = 1
	 ,@ErrMsg		NVARCHAR(MAX) = '' OUTPUT
	 ,@ErrCode		TINYINT = 0 OUTPUT
AS
/*
	Created: 20190815@Eden
	Task : Delete Bet Restriction Customer 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP [RedmineID: #117727]
	- 20240911@Johnson: Apply Inhouse for BLC [redmine:#209892]
	Parameter explanation:
	@ErrCode = :
			0 - succeed 
			4 - This record no longer exists in the Bet Restriction List.

	Example: 
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_CustomerDel 
	    @CustID = 15924397,	
		@UserID = 8,
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT
	SELECT @ErrCode, @ErrMsg
	
	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31703
	DECLARE @site  NVARCHAR(50)
	DECLARE @UserName	NVARCHAR(50)

	SET @ErrCode = 0

	SET @StartRun = GETDATE()

	SELECT @site = Site FROM Customer c WITH(NOLOCK) WHERE c.custid = @CustID
	
	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM BetRestriction_Customer WITH(NOLOCK)
					WHERE CustID = @CustID AND SportType = @SportType )
	BEGIN
		SET @ErrCode = 4
		SELECT @ErrMsg = 'This record no longer exists in the Bet Restriction List.'
		RETURN
	END

	SELECT @UserName = username FROM Customer WITH(NOLOCK) WHERE custid = @CustID
	
	BEGIN TRY
		DELETE t
		OUTPUT DELETED.CustID, DELETED.SportType, dbo.f_GetDateTime2()
		INTO BetRestriction_Customer_Del_InHouse(CustID,SportType,RepUpdateTime)
		FROM BetRestriction_Customer t WITH(UPDLOCK,ROWLOCK)
		WHERE CustID = @CustID AND SportType = @SportType
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SELECT @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @LogData VARCHAR(500)
	SELECT  @LogData = '<R '
						+ 'UserName="'+ coalesce(cast(@UserName as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />'
		

	IF @site = 'CN88'
	BEGIN
		EXEC dbo.CS_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionID,
			@TrackingValue		= @LogData,
			@Duration			= @Duration
	END
	ELSE -- MBC
	BEGIN
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserId				= @UserId,
			@CustId				= @CustId,
			@ActionId			= @ActionID,
			@TrackingValue		= @LogData,
			@Duration			= @Duration
	END	  
END
GO


