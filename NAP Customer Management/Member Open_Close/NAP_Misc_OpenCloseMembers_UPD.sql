CREATE PROCEDURE NAP_Misc_OpenCloseMembers_UPD
	@CustIDs varchar(500),
	@UserID int,
	@UpdateType tinyint,
	@UpdatedCount int = 0 output,
	@Language varchar(2) = 'E',
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@IP varchar(15)=''
AS
/*
Created: 20080911@whoknow
Task : Update status 'closed' for customer
DB: DBTXN/CustDB
Original:
Param's Explanation:
	• @custid: list custid need to be updated
	• @updatetype: 1: close account
					2: open account
*/

SET NOCOUNT ON
declare @close bit,@listcust varchar(500)=''
declare @TempCust (custid int)

declare @startRun datetime
declare @endRun datetime
declare @duration int
set @startRun = getdate()

IF(@updatetype=1)
BEGIN
	insert into @TempCust
	select custid from custinfo(nolock) where custid in (select val from dbo.StrSplit(@CustIDs,',')) and closed = 0
	
	update custinfo with(rowlock,updlock) set closed = 0 where custid in (select custid from @TempCust)
	if (@@error <> 0)
	begin
		Select @ErrMsg =
						case @Language 
							when 'E' then 'Update process is unsuccessful !'
							ELSE [dbo].[f_Get_MsgNamebyMsgID](90001,@Language)
						end	, @ErrCode = 101
		return
	end
	
	select @listcust = @listcust + cast(custid as varchar(10)) + ',' from @TempCust
	if isnull(@listcust,'')='' set @listcust = left(@listcust,len(@listcust)-1)
	
	set @endRun = getdate()
	set @duration  = datediff (millisecond,@startRun,@endRun)
	BEGIN TRY
		exec DBLOG.bodb_CustomerLog.dbo.[WriteLog_CloseOpenMultipleCustID_UserLog_RunSP]
			@UserID = @UserID,
			@CustIDs = @listcust,
			@SPName = 'NAP_Misc_OpenCloseMembers_UPD',
			@Doing	= NULL, --
			@Closed =1,
			@ActionID = '1148',	
			@Language = @Language,
			@IP =@IP,
			@ErrCode = @ErrCode ,
			@ErrMsg = @ErrMsg,
			@Duration = @Duration
	END TRY	
	BEGIN CATCH
		exec bodb_CustomerLog.dbo.[WriteLog_CloseOpenMultipleCustID_UserLog_RunSP]
			@UserID = @UserID,
			@CustIDs = @listcust,
			@SPName = 'NAP_Misc_OpenCloseMembers_UPD',
			@Doing	= NULL, --
			@Closed =1,
			@ActionID = '1148',	
			@Language = @Language,
			@IP =@IP,
			@ErrCode = @ErrCode ,
			@ErrMsg = @ErrMsg,
			@Duration = @Duration
	END CATCH
	select @updatedcount = count(*)	from @TempCust
END	

IF(@updatetype=2)
BEGIN
	insert into @TempCust
	select custid from custinfo(nolock) where custid in (select val from dbo.StrSplit(@CustIDs,',')) and closed = 1
	
	update custinfo with(rowlock,updlock) set closed = 0 where custid in (select custid from @TempCust)
	if (@@error <> 0)
	begin
		Select @ErrMsg =
						case @Language 
							when 'E' then 'Update process is unsuccessful !'
							ELSE [dbo].[f_Get_MsgNamebyMsgID](90001,@Language)
						end	, @ErrCode = 101
		return
	end
	
	select @listcust = @listcust + cast(custid as varchar(10)) + ',' from @TempCust
	if isnull(@listcust,'')='' set @listcust = left(@listcust,len(@listcust)-1)
	
	set @endRun = getdate()
	set @duration  = datediff (millisecond,@startRun,@endRun)
	
	BEGIN TRY
		exec DBLOG.bodb_CustomerLog.dbo.[WriteLog_CloseOpenMultipleCustID_UserLog_RunSP]
			@UserID = @UserID,
			@CustIDs = @listcust,
			@SPName = 'NAP_Misc_OpenCloseMembers_UPD',
			@Doing	= NULL, --
			@Closed =1,
			@ActionID = '1148',	
			@Language = @Language,
			@IP =@IP,
			@ErrCode = @ErrCode ,
			@ErrMsg = @ErrMsg,
			@Duration = @Duration
	END TRY	
	BEGIN CATCH
		exec bodb_CustomerLog.dbo.[WriteLog_CloseOpenMultipleCustID_UserLog_RunSP]
			@UserID = @UserID,
			@CustIDs = @listcust,
			@SPName = 'NAP_Misc_OpenCloseMembers_UPD',
			@Doing	= NULL, --
			@Closed =1,
			@ActionID = '1148',	
			@Language = @Language,
			@IP =@IP,
			@ErrCode = @ErrCode ,
			@ErrMsg = @ErrMsg,
			@Duration = @Duration
	END CATCH
		
	select @updatedcount = count(*)	from @TempCust
END



















