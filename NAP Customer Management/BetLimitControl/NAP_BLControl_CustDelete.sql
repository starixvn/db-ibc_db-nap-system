/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_CustDelete] 
	@CustID INT = NULL,
	@BetLimitTypeID INT = NULL,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMsg VARCHAR(200) = '' OUTPUT,
	@UserId INT = 0 ,
	@IP	VARCHAR(15) = ''
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - Remove CustSetting 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]
	- 20210513@Eden: BLC by pecentage of Match Max Bet [RedmineID: #154984]
	- 20240830@Johnson: Apply Inhouse for BLC [redmine:#209892]
	Parameter explanation:
	- @ErrorCode: 

	Example: 
	DECLARE @ErrorCode INT = 0 ,@ErrorMsg VARCHAR(200) = '' 
	EXEC NAP_BLControl_CustDelete 
		@CustID = 1,
		@BetLimitTypeID  = 1,
		@ErrorCode = @ErrorCode OUTPUT,
		@ErrorMsg = @ErrorMsg OUTPUT,
		@UserId = 8

	SELECT @ErrorCode,@ErrorMsg

	*/
BEGIN
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @ActionID INT = 31755
	DECLARE @site  NVARCHAR(50), @BetLimitType VARCHAR(50),@IsLicensee BIT

	SET @StartRun = GETDATE()

	EXEC NAP_UserControl.dbo.NAP_User_CheckPermission 
		@UserId=@userid,
		@SiteKey='CustomerManagement',
		@FunctionKey='BetLimitControl',
		@ErrCode=@ErrorCode OUTPUT,
		@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		RETURN

	SELECT @site = s.Site,@IsLicensee = st.isLicensee
	FROM Customer c WITH(NOLOCK) 
		INNER JOIN Customer s WITH(NOLOCK) ON c.srecommend = s.custid
		INNER JOIN Site st WITH(NOLOCK) On st.site = s.site
	WHERE c.custid = @CustID

	DECLARE @FunctionKey NVARCHAR(50)

	SELECT @FunctionKey = CASE  WHEN @site = 'CN88' THEN 'BLC_CN88Site'
								WHEN @IsLicensee = 1 THEN 'BLC_LicenseeSite'
								ELSE 'BLC_Credit' 
							END

	EXEC DBCUST.NAP_UserControl.dbo.NAP_User_CheckPermission 
			@UserId=@userid,
			@SiteKey='CustomerManagement',
			@FunctionKey=@FunctionKey,
			@Policy=1,
			@ErrCode=@ErrorCode OUTPUT,
			@ErrMsg=@ErrorMsg OUTPUT

	IF @ErrorCode <> 0
		RETURN

	DECLARE @OldMaxBet MONEY ,
		@OldMaxPerMatch MONEY,
		@OldMode TINYINT

	SELECT @OldMaxBet = t.MaxBet
		,@OldMaxPerMatch = t.MaxPerMatch
		,@OldMode = Mode
	FROM BetLimitControlCustSetting t WITH(NOLOCK)
	WHERE CustID = @CustID and BetLimitTypeID = @BetLimitTypeID 
	
	IF @@ROWCOUNT = 0
	BEGIN
		SET @ErrorCode = 4
		SELECT @ErrorMsg = 'The Bet Limit does not exist.'
		RETURN
	END

	DELETE t
	OUTPUT DELETED.CustID, DELETED.BetLimitTypeID, dbo.f_GetDateTime2()
	INTO BetLimitControlCustSetting_Del_Inhouse(CustID,BetLimitTypeID,RepUpdateTime)
	FROM BetLimitControlCustSetting t WITH(ROWLOCK,UPDLOCK)
	WHERE CustID = @CustID and BetLimitTypeID = @BetLimitTypeID 

	SELECT @BetLimitType = BetLimitType FROM BetLimitControlType WITH(NOLOCK) WHERE BetLimitTypeID = @BetLimitTypeID

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF (MILLISECOND, @StartRun, @EndRun)

	DECLARE @LogData VARCHAR(500)
	SELECT  @LogData = '<R '
						+ 'Type="'+ coalesce(cast(@BetLimitType as varchar(50)),space(1)) + '" ' 
						+ 'Mode="'+ coalesce(CASE WHEN @OldMode = 1 THEN 'Fixed Value' ELSE 'X times of Odds'' Max Bet' END ,space(1)) + '" ' 
						+ 'mpm="'+ coalesce(cast(@OldMaxPerMatch as varchar(50)),space(1)) + '" '
						+ 'maxb="'+ coalesce(cast(@OldMaxBet as varchar(50)),space(1)) + '" ' 
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


