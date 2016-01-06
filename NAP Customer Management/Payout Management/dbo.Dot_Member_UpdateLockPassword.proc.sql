USE [CustDB]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Member_UpdateLockPassword]    Script Date: 1/6/2016 2:06:10 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Dot_Member_UpdateLockPassword]
	@CustID int,
	@status bit=1,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT 
AS
/*
Created: 20151228@Austin
Task : #47290 - Colossus Bets & MCG RnG Casino Payout Management
DB: DBTXN.bodb02
Original:
Revisions:
	-- 20151228@Austin CREATE
	
Param's Explanation:
	
*/
BEGIN

	SET NOCOUNT ON;
	
	UPDATE dbo.custInfo with (ROWLOCK, UPDLOCK)
		SET LockUpd = @status		
		WHERE custid = @CustID

	select @ErrCode = @@ROWCOUNT -1 ,@ErrMsg = CASE WHEN  @ErrCode = 0 THEN 'success' ELSE 'user not found' END 
   
END
