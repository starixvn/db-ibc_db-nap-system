 ALTER PROCEDURE [dbo].[Nap_CustomerSelIDByUserNameNickName]
	@username	NVARCHAR(30) = '',
	@custid		INT = 0 OUTPUT
AS
	/*
		Created: Johnson
		Date: 2014-06-23
		Task: get custid by username/nickname
		DB: DBACC/bodb02
	*/
BEGIN
	SET NOCOUNT ON
	
	SELECT @custid = custid 
	FROM customer WITH(NOLOCK) 
	WHERE username = @username OR username2 = @username
END
GO

GRANT EXECUTE ON [dbo].[Nap_CustomerSelIDByUserNameNickName] TO [bodbAdminNet]
	