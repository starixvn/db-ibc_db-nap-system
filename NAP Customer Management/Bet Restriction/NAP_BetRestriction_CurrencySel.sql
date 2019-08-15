/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CurrencySel] 
	 @PageSize		INT = 50
	,@PageIndex		INT = 1
	,@TotalPages	INT = 1 OUTPUT
	,@TotalItems	INT = 0 OUTPUT
	,@IsTest		BIT = 0
AS
/*
	Created: 20190815@Eden
	Task : Get Bet Restriction Currency 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP [RedmineID: #117727]

	Example:   
	declare @TotalPages	INT 
		,@TotalItems	INT 
	EXEC NAP_BetRestriction_CurrencySel 
		@PageSize	= 10,
		@PageIndex	= 1,
		@TotalPages = @TotalPages OUTPUT,
		@TotalItems = @TotalItems OUTPUT,
		@IsTest = 1
	select @TotalItems,@TotalPages
	*/
BEGIN
	DECLARE @RowCount int, @RowStart int, @RowEnd int

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

	SELECT DISTINCT SportType,
		   IsShowData = CASE WHEN BackEndStatus <=  @IsTest THEN 1 ELSE 0 END
	INTO  #Setting
	FROM  BetRestriction_Setting WITH (NOLOCK)
	WHERE RestrictionLevel = 'BetRestriction_Currency'

	SELECT e.currency, 
		   bc.ExchangeID,
		   bc.SportType,
		   bc.[Type], 
		   bc.LiveBetAccept, 
		   bc.SeizeBetTicket, 
		   bc.FollowAccount AS FollowAccountID,
		   ci.username AS FollowAccount,
		   ROW_NUMBER() OVER (ORDER BY e.currency) AS RowNumber
	INTO #BetRestriction_Currency
	FROM BetRestriction_Currency bc WITH(NOLOCK)
		 INNER JOIN exchange e WITH(NOLOCK) ON bc.ExchangeID = e.exchangeid
		 LEFT JOIN CustInfo ci WITH(NOLOCK) ON ci.custid = bc.FollowAccount
		 INNER JOIN #Setting st WITH(NOLOCK) ON bc.SportType = st.SportType AND st.IsShowData = 1

	SELECT @TotalItems = COUNT(1),@TotalPages=@TotalItems/@PageSize + CASE WHEN @TotalItems%@PageSize > 0 THEN 1 ELSE 0 END  
	FROM #BetRestriction_Currency

	SELECT * 
	FROM #BetRestriction_Currency
	WHERE RowNumber BETWEEN @rowstart AND @rowend 	

END
GO


