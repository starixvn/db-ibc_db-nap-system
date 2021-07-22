/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_Misc_OpenCloseMembers_UPD]
	@CustIDs varchar(8000),
	@UserID int,
	@UpdateType tinyint,
	@UpdatedCount int = 0 output,
	@Language varchar(2) = 'E',
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(500) = '' OUTPUT,
	@IP varchar(15)='',
	@ListCustRemove varchar(max) = '' OUTPUT
AS
BEGIN
	/*
	Created: 20080911@whoknow
	Task : Update status 'closed' for customer
	DB: DBTXN/CustDB
	Original:

	Revisions:
			--20170601@Winnie: Apply color for closed account [RedmineID: #74494]
			- 20210505@Tina: Lock account & indirect close account [redmine: #148600]

	Explanation's Param:
		• @custid: list custid need to be updated
		• @updatetype: 0: close account
						1: open account
	*/

	SET NOCOUNT ON
	declare @close bit,@listcust varchar(500)='', @ListCustRemoveID varchar(max)=''
	declare @TempCust TABLE(custid int)
	declare @TempCustRemove TABLE(custid int)

	declare @startRun datetime
	declare @endRun datetime
	declare @duration int
	set @startRun = getdate()

	IF(@updatetype=0)
	BEGIN
		insert into @TempCust
		select custid from CustProductStatus(nolock) where custid in (select val from dbo.StrSplit(@CustIDs,',')) and CloseInfo = 0
		if not exists (select top 1 1 from @TempCust)
		begin
			select @ErrMsg = 'Cannot update ! Members are closed',
					@ErrCode = 102
			return;
		end

		UPDATE CustProductStatus with(rowlock,updlock) set CloseInfo = 1 where custid in (select custid from @TempCust)

		UPDATE CustLoginInfo_Member with(rowlock,updlock) SET ClosedReason=1  where custid in (select custid from @TempCust)

		INSERT INTO [CustLoginInfo_Member]([CustID],[SecurityCode],[IP],[LastChangedID],[LastChangedDate],ClosedReason)
		SELECT t.Custid,NULL,@IP,@UserID,GETDATE(),1
		FROM @TempCust t
		INNER JOIN Customer c WITH(NOLOCK) ON t.custid=c.custid
		LEFT JOIN CustLoginInfo_Member cl WITH(NOLOCK) ON t.custid=cl.CustID
		WHERE cl.custid IS NULL AND c.roleid=1

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
				EXEC DBLOG.bodb_CustomerLog.dbo.[WriteLog_CloseOpenMultipleCustID_UserLog_RunSP]
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
				EXEC bodb_CustomerLog.dbo.[WriteLog_CloseOpenMultipleCustID_UserLog_RunSP]
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
		select custid from CustProductStatus(nolock) where custid in (select val from dbo.StrSplit(@CustIDs,',')) and CloseInfo > 0
	
		if not exists (select top 1 1 from @TempCust)
		begin
			select @ErrMsg = 'Cannot update ! Members are opened',
					@ErrCode = 102
			return;
		end

		DELETE T
		OUTPUT DELETED.CustID
		INTO @TempCustRemove(CustID)
		FROM @TempCust T
			INNER JOIN CustProductStatus cps WITH (NOLOCK) ON t.custID = cps.custID
			CROSS APPLY (SELECT * FROM f_GetInfoStatus(cps.CloseInfo)) AS cl
		WHERE (cl.SuperStatus + cl.MasterStatus + cl.AgentStatus) > 0

		UPDATE CustProductStatus with(rowlock,updlock) set CloseInfo = 0 where custid in (select custid from @TempCust)

		UPDATE CustLoginInfo_Member with(rowlock,updlock) SET ClosedReason=0  where custid in (select custid from @TempCust)

		INSERT INTO [CustLoginInfo_Member]([CustID],[SecurityCode],[IP],[LastChangedID],[LastChangedDate],ClosedReason)
		SELECT t.Custid,NULL,@IP,@UserID,GETDATE(),0
		FROM @TempCust t
		INNER JOIN Customer c WITH(NOLOCK) ON t.custid=c.custid
		LEFT JOIN CustLoginInfo_Member cl WITH(NOLOCK) ON t.custid=cl.CustID
		WHERE  cl.custid  IS NULL AND c.roleid=1

		IF (@@ERROR <> 0)
		BEGIN
			SELECT @ErrMsg =
							CASE @Language 
								WHEN 'E' THEN 'Update process is unsuccessful !'
								ELSE [dbo].[f_Get_MsgNamebyMsgID](90001,@Language)
							END	, @ErrCode = 101
			RETURN
		END

		select @listcust = @listcust + cast(custid as varchar(10)) + ',' from @TempCust
		if isnull(@listcust,'')<>'' set @listcust = left(@listcust,len(@listcust)-1)

		set @endRun = getdate()
		set @duration  = datediff (millisecond,@startRun,@endRun)
	
		BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.[WriteLog_CloseOpenMultipleCustID_UserLog_RunSP]
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
				EXEC bodb_CustomerLog.dbo.[WriteLog_CloseOpenMultipleCustID_UserLog_RunSP]
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
		
		SELECT @updatedcount = count(*)	from @TempCust

		IF EXISTS(SELECT TOP 1 1 FROM @TempCustRemove)
		BEGIN
			SELECT @ErrMsg =  CASE @Language 
									WHEN 'E' THEN 'This user''s upline was closed. Cannot edit.'
									ELSE [dbo].[f_Get_MsgNamebyMsgID](60003,@Language)
								END, @ErrCode = 105
			
			SELECT @ListCustRemove = STUFF((
            SELECT ', ' + ci.username
            FROM @TempCustRemove T
				JOIN custInfo ci WITH (NOLOCK) ON ci.custid = t.custid
            FOR XML PATH('')
            ), 1, 1, '')

			SELECT @ListCustRemoveID = STUFF((
            SELECT ', ' + CAST(T.custid AS VARCHAR(16))
            FROM @TempCustRemove T
            FOR XML PATH('')
            ), 1, 1, '')

			BEGIN TRY
					EXEC DBLOG.bodb_CustomerLog.dbo.[WriteLog_CloseOpenMultipleCustID_UserLog_RunSP]
					@UserID = @UserID,
					@CustIDs = @ListCustRemoveID,
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
					EXEC bodb_CustomerLog.dbo.[WriteLog_CloseOpenMultipleCustID_UserLog_RunSP]
					@UserID = @UserID,
					@CustIDs = @ListCustRemoveID,
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

		END
	END
END