/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_nap" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_AdminInfo_Update]
	@custid INT,
	@FirstName			NVARCHAR (50)	=	NULL,
	@LastName			NVARCHAR (50)	=	NULL,
	@Email				NVARCHAR (50)	=	NULL,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(500) = '' OUTPUT
AS

/*
	Created: 20120709@Edward
	Task : Update NAP user information and bodb02.dbo.Customer
	DB: DBCUST/CUSTDB
	Original:

	Revisions:
	    - 20241129@Johnson: Apply In-house replication for Credit Setting [RedmineID: #212684]		
	Param's Explanation:
	• @CustId :
		= custid from bodb02.dbo.Customer		
	• @ErrCode: 
	• @ErrMsg: Error description.
*/

-- Update general admin user information
UPDATE Customer WITH (ROWLOCK, UPDLOCK)	
SET 
	firstname = @FirstName,
	lastname = @LastName,
	email = @Email,
	RepUpdateTime = dbo.f_GetDateTime2()
WHERE custid = @CustID
IF (@@error <> 0)
BEGIN
	SELECT @ErrMsg = 'Update user information failed.',
	@ErrCode = 103

	RETURN
END


GO