/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_SiteDel] 
	  @SiteID		INT = NULL
	 ,@UserId		INT
	 ,@IP			VARCHAR(15) = ''
	 ,@SportType	SMALLINT = 1
	 ,@ErrMsg		NVARCHAR(MAX) = '' OUTPUT
	 ,@ErrCode		TINYINT = 0 OUTPUT
AS
/*
	Created: 20190815@Eden
	Task : Delete Bet Restriction Site 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]
	- 20240911@Johnson: Apply Inhouse for BLC [redmine:#209892]
	Parameter explanation:
	@ErrCode = :
			0 - succeed
			4 - This record no longer exists in the Bet Restriction List.

	Example: 
	declare @ErrMsg NVARCHAR(MAX),@ErrCode TINYINT
	EXEC NAP_BetRestriction_SiteDel 
		@SiteID = 1,
		@UserID = 8,
		@ErrMsg = @ErrMsg OUTPUT,
		@ErrCode =@ErrCode OUTPUT
	SELECT @ErrCode, @ErrMsg
	
	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31706
	DECLARE @site NVARCHAR(50)

	SET @ErrCode = 0
	SET @StartRun = GETDATE()

	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM BetRestriction_Site WITH(NOLOCK)
					WHERE SiteID = @SiteID
						  AND SportType = @SportType)
	BEGIN
		SET @ErrCode = 4
		SELECT @ErrMsg = 'This record no longer exists in the Bet Restriction List.'
		RETURN
	END
	
	SELECT @Site = Site FROM Site WITH(NOLOCK) WHERE siteid = @SiteID

	BEGIN TRY
		DELETE t
		OUTPUT DELETED.siteid, DELETED.SportType, dbo.f_GetDateTime2()
		INTO BetRestriction_Site_Del_Inhouse(siteid,SportType,RepUpdateTime)
		FROM BetRestriction_Site t WITH(UPDLOCK,ROWLOCK)
		WHERE siteid = @SiteID AND SportType = @SportType
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
						+ 'Site="'+ coalesce(cast(@Site as varchar(50)),space(1)) + '" ' 
						+ 'SportType="'+ coalesce(cast(@SportType as varchar(50)),space(1)) + '" ' 
						+ 'IP="' + COALESCE(@IP, SPACE(1)) + '" '
						+ ' />'
		

	EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
		@UserId				= @UserId,
		--@CustId				= @CustId,
		@ActionId			= @ActionID,
		@TrackingValue		= @LogData,
		@Duration			= @Duration
		  
END
GO


