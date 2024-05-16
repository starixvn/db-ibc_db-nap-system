/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_PayoutPromotion_VerifySel]     
     @DrawID	INT = 0
	,@Username	VARCHAR(30) = ''
	,@VerificationCode	VARCHAR(50) = ''
	,@TypeID		TINYINT
	,@Errcode	INT = 0 OUTPUT
	,@ErrMsg	NVARCHAR(MAX) = '' OUTPUT
AS    
/*    
    Created by: Tacy@20240328
    Task : Get Payout Promotion List 
    DB: DBACC/bodb02    
    
	Revisions:
        - 20240328@Tacy: NAP CM - Correct Score Promotion [redmine: #202974]
		- 20240514@Tacy: remove teamname [redmine: #205071]
		
	Param's Explanation:

*/    
BEGIN    
    SET NOCOUNT ON ;

	IF (@DrawID<>0 AND (@Username<>'' OR @VerificationCode<>''))
	BEGIN
		SELECT @Errcode=99
			, @ErrMsg='Input wrong value'

		RETURN
	END

	IF @DrawID = 0
	BEGIN
		IF @Username='' OR @VerificationCode=''
		BEGIN
			SELECT @Errcode=100
				, @ErrMsg='Please input Username and Verification code'

			RETURN
		END

		--Invalid username
		IF NOT EXISTS (SELECT 1 FROM Customer WITH (NOLOCK)
						WHERE username=@Username AND roleid=1)
		BEGIN
			SELECT @Errcode=101
				, @ErrMsg='Invalid member'

			RETURN
		END
	END 
	ELSE
	BEGIN
		--available DRAW
		IF NOT EXISTS (SELECT TOP 1 1 FROM LuckyDrawList WITH (NOLOCK)
						WHERE DrawID=@DrawID AND IsDeleted=0)
		BEGIN
			SELECT @ErrCode=103
				,@ErrMsg='The draw - ' + CAST(@DrawID AS varchar) + ' is not available.'

			RETURN
		END
	END 

	--Invalid verification code
	IF NOT EXISTS (SELECT 1 FROM LuckyDrawList ld WITH (NOLOCK)
				   INNER JOIN Customer c WITH (NOLOCK)
							ON c.custid=ld.custid
				   WHERE VerificationCode=@VerificationCode AND IsDeleted=0
					AND ld.TypeID=@TypeID
					AND ((@DrawID=0 AND c.username=@Username) OR ld.DrawID=@DrawID))
	BEGIN
		SELECT @Errcode=102
			, @ErrMsg='Invalid code'

		RETURN
	END

	SELECT ld.DrawID, ld.TypeID
		, c.custid, c.username, c.site
		,ld.Payout AS Amount, ld.Currency
		,ld.ExpiredDate, ld.matchid
	FROM LuckyDrawList ld WITH (NOLOCK)
	INNER JOIN customer c WITH (NOLOCK) ON c.custid=ld.custid
	WHERE ld.IsDeleted=0 AND ld.IsLicensee=0 --credit account
		AND (@DrawID=0 OR ld.DrawID=@DrawID)
		AND ld.TypeID=@TypeID
		AND (@VerificationCode='' OR ld.VerificationCode=@VerificationCode)
		AND (@Username='' OR c.username=@Username)
END
GO