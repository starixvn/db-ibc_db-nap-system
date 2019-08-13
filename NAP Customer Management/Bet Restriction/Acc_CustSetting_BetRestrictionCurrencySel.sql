/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCurrencySel] 
	 @PageSize		INT = 50
	,@PageIndex		INT = 1
	,@TotalPages	INT = 1 OUTPUT
	,@TotalItems	INT = 0 OUTPUT
	,@IsTest		BIT = 0
AS
/*
	Created: 20190807@Eden
	Task : Get Bet Restriction Currency 
	DB: DBCUST/CustDB
	Original:

	Example:   
	declare @TotalPages	INT 
		,@TotalItems	INT 
	EXEC Acc_CustSetting_BetRestrictionCurrencySel 
		@PageSize	= 10,
		@PageIndex	= 1,
		@TotalPages = @TotalPages OUTPUT,
		@TotalItems = @TotalItems OUTPUT,
		@IsTest = 1
	select @TotalItems,@TotalPages
	*/
BEGIN
	DECLARE @RowCount int, @RowStart int, @RowEnd int
	DECLARE @IsShowData BIT = 0

	IF EXISTS(	SELECT 1
				FROM BetRestriction_Setting WITH (NOLOCK)
				WHERE SportType = 1 AND SettingType = 3
				  AND SettingStatus <=  @IsTest )
	BEGIN
		SET @IsShowData = 1
	END

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	SELECT e.currency, 
		   bc.[Type], 
		   bc.LiveBetAccept, 
		   bc.SeizeBetTicket, 
		   bc.FollowAccount AS FollowAccountID,
		   ci.username AS FollowAccount,
		   ROW_NUMBER() OVER (ORDER BY e.currency) AS RowNumber
	INTO #BetRestriction_Currency
	FROM BetRestriction_Currency bc WITH(NOLOCK)
		 JOIN exchange e WITH(NOLOCK) ON bc.ExchangeID = e.exchangeid
		 LEFT JOIN CustInfo ci WITH(NOLOCK) ON ci.custid = bc.FollowAccount
	WHERE @IsShowData = 1

	SELECT @TotalItems = COUNT(1),@TotalPages=@TotalItems/@PageSize + CASE WHEN @TotalItems%@PageSize > 0 THEN 1 ELSE 0 END  
	FROM #BetRestriction_Currency

	SELECT * 
	FROM #BetRestriction_Currency
	WHERE RowNumber BETWEEN @rowstart AND @rowend 	

END
GO


