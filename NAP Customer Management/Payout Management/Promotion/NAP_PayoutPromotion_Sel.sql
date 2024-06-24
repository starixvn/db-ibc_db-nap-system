/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_PayoutPromotion_Sel]     
     @TypeID	TINYINT
	,@MatchID	INT
	,@Username	VARCHAR(30)=''
	,@VerificationCode	VARCHAR(50)=''
	,@Status	VARCHAR(10)=''	--ALL
	,@IsExpired	BIT=0
	,@IsTest	BIT=0
	,@PageSize	INT = 50
	,@PageIndex	INT = 1
	,@TotalItems INT = 0 OUTPUT
AS    
/*    
    Created by: Tacy@20240328
    Task : Get Payout Promotion List
    DB: DBACC/bodb02    
    
	Revisions:
        - 20240328@Tacy: NAP CM - Correct Score Promotion [redmine: #202974]
		- 20240514@Tacy: remove teamname [redmine: #205071]
		- 20240624@Tacy: Change ExpiredDate condition [redmine: #206974]
		
	Param's Explanation:
		* @TypeID :	1 ~ Correct Score Lucky Draw
					2 ~ 6 Scores EC24 Challenge

		* @MatchID : 0 ~ All matches

		* @Status : ''~ ALL Status
					0 ~ Open
					1 ~ Verified
					2 ~ Completed
					3 ~ Cancelled

*/    
BEGIN    
    SET NOCOUNT ON ;

	DECLARE @Rowstart INT, @RowEnd INT
		, @crrDateGMT8  DATETIME  
	
	SET @crrDateGMT8 = DATEADD(HOUR,12,GETDATE())  

	CREATE TABLE #tblLuckyDrawList (
		rn INT IDENTITY(1,1),
		DrawID INT,
		custid INT,
		Username VARCHAR(30),
		Site VARCHAR(50),
		Amount MONEY,
		Currency VARCHAR(12),
		matchid	INT,
		Status VARCHAR(10),
		CreatedDate DATETIME,
		ExpiredDate DATE,		--GMT+8
		PaymentDate DATE,
		LastModifiedDate DATETIME,
		LastModifiedUser VARCHAR(30),
		Remark nVARCHAR(1000),
	)

	INSERT INTO #tblLuckyDrawList
		(DrawID, custid, Username, Site
		, Amount, Currency, matchid
		, Status, CreatedDate, ExpiredDate, PaymentDate
		, LastModifiedDate, LastModifiedUser, Remark)
	SELECT ld.DrawID, c.custid, c.username, c.site
		,ld.Payout AS Amount, ld.Currency
		,ld.matchid
		,CASE WHEN ld.StatusID=0 THEN 'Open'
			  WHEN ld.StatusID=1 THEN 'Verified'
			  WHEN ld.StatusID=2 THEN 'Completed'
			  WHEN ld.StatusID=3 THEN 'Cancelled'
		END AS [Status]
		,ld.CreatedDate, ld.ExpiredDate, ld.SettledDate AS PaymentDate
		,ld.LastModifiedDate, cu.username AS LastModifiedUser
		,ld.Remark
	FROM LuckyDrawList ld WITH (NOLOCK)
	INNER JOIN customer c WITH (NOLOCK) ON c.custid=ld.custid
	LEFT JOIN customer cu WITH (NOLOCK) ON cu.custid=ld.LastModifiedUserID
	WHERE ld.IsDeleted=0 AND ld.IsLicensee=0 --credit account
		AND ld.TypeID=@TypeID
		AND (@MatchID=0 OR ld.matchid=@MatchID)
		AND (@VerificationCode='' OR ld.VerificationCode=@VerificationCode)
		AND (@Username='' OR c.username=@Username)
		AND (@Status='' OR ld.StatusID=CAST(@Status AS TINYINT))
		AND 1 = CASE WHEN @IsExpired=0 THEN 1
					 WHEN @IsExpired=1 AND ld.ExpiredDate<CAST(@crrDateGMT8 AS DATE) THEN 1
				ELSE 0 END
		AND ld.IsTest<=@IsTest
	ORDER BY ld.CreatedDate DESC
		, ld.StatusID, c.username

	SELECT @TotalItems = COUNT(1) FROM #tblLuckyDrawList

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	SELECT DrawID, custid, Username, Site
		, Amount, Currency, matchid
		, Status, CreatedDate, ExpiredDate, PaymentDate
		, LastModifiedDate, LastModifiedUser, Remark
	FROM #tblLuckyDrawList
	WHERE rn BETWEEN @RowStart AND @RowEnd
END
GO