ALTER PROCEDURE [dbo].[NAP_Misc_OpenCloseMembers_List] 
	@username varchar(30),
	@TotalItems int = 0 output,
	@ItemPerPage int = 50,
	@PageIndex int = 1,
	@IsClosed int = -1,
	@ErrorCode int = null output,
	@ErrorMsg varchar(max) = '' output,
	@Language varchar(2)= 'E'
AS

/*
Created: 2014-03-13
Author: Dom
Task : get list of accounts to close/open
DB: DBAGE/bodb02
Original:
*/

declare @custid int = null,
		@roleid	int = null
declare @closedacc TABLE(custid int)

select @custid = custid, @roleid = roleid from custinfo(nolock) 
where username = @username 
	and roleid <> 1
	and closed = 0

IF(@roleid=4)
begin
	insert into @closedacc
	select custid from custInfo(nolock) where srecommend = @custid and (roleid in(2,3)) and closed=1
end
else if(@roleid=3)
begin
	insert into @closedacc
	select custid from custInfo(nolock) where mrecommend = @custid and roleid=2 and closed=1
end

if(@custid is null)
begin
	select @errorcode  = MsgID,
			@errormsg = MsgNameEN
	from MsgError WHERE MsgID=40019
	Select @ErrorMsg = [dbo].[f_Get_MsgNamebyMsgID](40001,@Language)	
		,@ErrorCode = 201
	return;
end

;WITH CustomerTemp AS
(
select ROW_NUMBER() OVER (ORDER BY username) as row, custid from custinfo(nolock)
where (srecommend = @custid or mrecommend = @custid or recommend=@custid )
		and roleid=1
		and (@IsClosed = -1 or closed = @IsClosed)
		and srecommend not in (select custid from dep_custsuper)
		and mrecommend not in(SELECT custid from @closedacc)
		and recommend not in(SELECT custid from @closedacc)
) 
select custid,total,row 
into #temp
from CustomerTemp 
OUTER APPLY (
	select max(row) total  from CustomerTemp
)A
where row between @ItemPerPage*@PageIndex - @itemperpage+1 and @ItemPerPage*@PageIndex

select top 1 @TotalItems = total from #temp 
if @roleid = 4
begin
	select ci.custid,
			master.username master,
			agent.username agent,
			ci.username member, 
			ci.SyncCasino,
			ci.closed
	from custInfo(NOLOCK) ci
	inner join custInfo(NOLOCK) master on master.custid = ci.mrecommend
	inner join custInfo(NOLOCK) agent on agent.custid = ci.recommend
	where ci.custid in(select custid from #temp)
	order by master.username,
			agent.username,
			ci.username
end
else if @roleid = 3
begin
	select ci.custid,
			agent.username agent,
			ci.username member, 
			ci.SyncCasino,
			ci.closed
	from custInfo(NOLOCK) ci
	inner join custInfo(NOLOCK) agent on agent.custid = ci.recommend
	where ci.custid in(select custid from #temp)
	order by agent.username,
			ci.username
end
else if @roleid = 2
begin
	select ci.custid,
			ci.username member, 
			ci.SyncCasino,
			ci.closed
	from custInfo(NOLOCK) ci
	where ci.custid in(select custid from #temp)
end

drop table #temp

/*
NAP_customerUpdClosebyList_sel
	@username = 'SSS',
	@TotalPages = 0 ,
	@ItemPerPage = 20,
	@PageIndex = 1

	select super.custid srecommend,super.username,count(ci.custid) count 
from custInfo(NOLOCK) ci
inner join custInfo(NOLOCK) super on super.custid = ci.srecommend
 GROUP by super.custid,super.username

 select * from MsgError
*/


