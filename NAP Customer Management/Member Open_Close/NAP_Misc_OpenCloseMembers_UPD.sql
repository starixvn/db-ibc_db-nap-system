ALTER PROCEDURE [dbo].[NAP_Misc_OpenCloseMembers_UPD]
	@CustIDs varchar(8000),
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
		--20170601@Winnie: Apply color for closed account
Param's Explanation:
	• @custid: list custid need to be updated
	• @updatetype: 0: close account
					1: open account
*/

SET NOCOUNT ON
declare @close bit,@listcust varchar(500)=''
declare @TempCust TABLE(custid int)

declare @startRun datetime
declare @endRun datetime
declare @duration int
set @startRun = getdate()

IF(@updatetype=0)
BEGIN
	insert into @TempCust
	select custid from custinfo(nolock) where custid in (select val from dbo.StrSplit(@CustIDs,',')) and closed = 0
	if not exists (select top 1 1 from @TempCust)
	begin
		select @ErrMsg = 'Cannot update ! Members are closed',
				@ErrCode = 102
		return;
	end

	update custinfo with(rowlock,updlock) set closed = 1 where custid in (select custid from @TempCust)

	UPDATE CustLoginInfo with(rowlock,updlock) SET ClosedReason=1  where custid in (select custid from @TempCust)

	UPDATE CustLoginInfo_Member with(rowlock,updlock) SET ClosedReason=1  where custid in (select custid from @TempCust)

	INSERT INTO [CustLoginInfo_Member]([CustID],[SecurityCode],[IP],[LastChangedID],[LastChangedDate],ClosedReason)
	SELECT t.Custid,NULL,@IP,@UserID,GETDATE(),1
	FROM @TempCust t
	INNER JOIN Customer c WITH(NOLOCK) ON t.custid=c.custid
	LEFT JOIN CustLoginInfo_Member cl WITH(NOLOCK) ON t.custid=cl.CustID
	WHERE t.custid IS NULL AND c.roleid=1

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
	if isnull(@listcust,'')<>'' set @listcust = left(@listcust,len(@listcust)-1)

	set @endRun = getdate()
	set @duration  = datediff (millisecond,@startRun,@endRun)
	BEGIN TRY
								exec DBLOG.bodb_CustomerLog.dbo.[WriteLog_CloseOpenMultipleCustID_UserLog_RunSP]
			@UserID = @UserID,
			@CustIDs = @listcust,
			@SPName = 'NAP_Misc_OpenCloseMembers_UPD',
			@Doing	= NULL, --
			@Closed =1,
			@ActionID = '1149',	
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
			@ActionID = '1149',	
			@Language = @Language,
			@IP =@IP,
			@ErrCode = @ErrCode ,
			@ErrMsg = @ErrMsg,
			@Duration = @Duration
	END CATCH
	select @updatedcount = count(*)	from @TempCust
END	

IF(@updatetype=1)
BEGIN
	insert into @TempCust
	select custid from custinfo(nolock) where custid in (select val from dbo.StrSplit(@CustIDs,',')) and closed = 1
	
	if not exists (select top 1 1 from @TempCust)
	begin
		select @ErrMsg = 'Cannot update ! Members are opened',
				@ErrCode = 102
		return;
	end

	select @listcust = @listcust + cast(custid as varchar(10)) + ',' from @TempCust
	if isnull(@listcust,'')<>'' set @listcust = left(@listcust,len(@listcust)-1)

	update custinfo with(rowlock,updlock) set closed = 0 where custid in (select custid from @TempCust)

	UPDATE CustLoginInfo with(rowlock,updlock) SET ClosedReason=0  where custid in (select custid from @TempCust)

	UPDATE CustLoginInfo_Member with(rowlock,updlock) SET ClosedReason=0  where custid in (select custid from @TempCust)

	INSERT INTO [CustLoginInfo_Member]([CustID],[SecurityCode],[IP],[LastChangedID],[LastChangedDate],ClosedReason)
	SELECT t.Custid,NULL,@IP,@UserID,GETDATE(),0
	FROM @TempCust t
	INNER JOIN Customer c WITH(NOLOCK) ON t.custid=c.custid
	LEFT JOIN CustLoginInfo_Member cl WITH(NOLOCK) ON t.custid=cl.CustID
	WHERE t.custid IS NULL AND c.roleid=1

	if (@@error <> 0)
	begin
		Select @ErrMsg =
						case @Language 
							when 'E' then 'Update process is unsuccessful !'
							ELSE [dbo].[f_Get_MsgNamebyMsgID](90001,@Language)
						end	, @ErrCode = 101
		return
	end

	
	select @listcust -- test 

	set @endRun = getdate()
	set @duration  = datediff (millisecond,@startRun,@endRun)
	
	BEGIN TRY
								exec DBLOG.bodb_CustomerLog.dbo.[WriteLog_CloseOpenMultipleCustID_UserLog_RunSP]
			@UserID = @UserID,
			@CustIDs = @listcust,
			@SPName = 'NAP_Misc_OpenCloseMembers_UPD',
			@Doing	= NULL, --
			@Closed =0,
			@ActionID = '1149',	
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
			@Closed =0,
			@ActionID = '1149',	
			@Language = @Language,
			@IP =@IP,
			@ErrCode = @ErrCode ,
			@ErrMsg = @ErrMsg,
			@Duration = @Duration
	END CATCH
		
	select @updatedcount = count(*)	from @TempCust
END