USE [CustDB]
GO
/****** Object:  StoredProcedure [dbo].[NAP_AdminInfo_Update]    Script Date: 8/1/2014 10:18:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.NAP_AdminInfo_Update    Script Date: 12/9/2013 12:53:47 PM ******/
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
	DB: DBTRANS.bodb02
	Original:

	Revisions:
	    
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
	email = @Email
WHERE custid = @CustID
IF (@@error <> 0)
BEGIN
	SELECT @ErrMsg = 'Update user information failed.',
	@ErrCode = 103

	RETURN
END


GO
GRANT EXECUTE ON [dbo].[NAP_AdminInfo_Update] TO [bodbAdminNet] AS [dbo]