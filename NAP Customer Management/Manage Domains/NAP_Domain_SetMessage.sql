/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Domain_SetMessage]
	@DomainList	NVARCHAR(MAX)
	,@IsTest BIT = 0
AS
/*
	Created: 20230911@Tacy
    Task: Send personal message for SMA when a Domain is changed status to "Active"
    DB: DBMSG-bodb_Message

	Revisions:
		- 20230911@Tacy: NAP CM - Manage Domain [RedmineID: #194024]
		- 20231114@Tacy: Update Thai Language [RedmineID: #194024]

	Param's Explanation:
		- @MsgContentsType: to identify normal message or changed settings message
				= 0 ~ Normal Data
				= 100 ~ msg from CRM site
				= 109 ~ msg from CWL
				= 110 ~ msg from NAP CM - Manage Domain

		- @DomainList:
				<DomainList>
					<Domain d="domain1.com" s="y789,y889,yOther,yUT" />
					<Domain d="domain2.com" s="y789,y889" />
				</DomainList>
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE	  @XML XML
			, @MessageId	INT
			, @Content_en	NVARCHAR(4000)
			, @Content_cs	NVARCHAR(4000)
			, @Content_ch	NVARCHAR(4000)
			, @Content_th	NVARCHAR(4000)
			, @Content_vn	NVARCHAR(4000)
			, @Site			VARCHAR(50)
			, @cnt			VARCHAR(5)

	CREATE TABLE #tbDomains (Site VARCHAR(30), cnt TINYINT, IsFinished BIT DEFAULT(0))

	SELECT @XML=CAST(@DomainList AS xml)

	;WITH tmp_Domains AS (
		SELECT t.s.value('@d','VARCHAR(50)') AS Domain
			, s.Site
		FROM @xml.nodes('DomainList/Domain') t(s)
		CROSS APPLY (SELECT TRIM(VALUE) Site 
					FROM STRING_SPLIT(t.s.value('@s','VARCHAR(200)'),',')) s
	)
	INSERT INTO #tbDomains (Site, cnt)
	SELECT SITE, COUNT(1)
	FROM tmp_Domains
	GROUP BY Site

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tbDomains)
		RETURN

	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) #tbDomains 
		SET @Site=Site, @cnt=cnt
			,IsFinished=1
		WHERE IsFinished=0

		IF @@ROWCOUNT = 0 
			BREAK;

		SELECT @Content_en = @cnt + N' domain(s) activated. You can find further details in Available Domains function.'
			, @Content_cs = @cnt +  N'域名已启用。您可以在可用域名功能中找到更多详细资讯。'
			, @Content_ch = @cnt +  N'域名已啟用。 您可以在可用域名功能中找到更多詳細資訊。'
			, @Content_th = N'เปิดใช้งาน ' + @cnt +  N' โดเมนแล้ว คุณสามารถดูรายละเอียดเพิ่มเติมได้ในฟังก์ชันโดเมนที่มีอยู่'
			, @Content_vn = @cnt +  N' tên miền đã được kích hoạt. Bạn có thể xem thêm chi tiết trong chức năng Tên Miền Khả Dụng.'

		--Insert Msg
		EXEC Age_Msg_SetMessage 
					@Content_en=@Content_en,
					@Content_ch=@Content_ch,
					@Content_cs=@Content_cs,
					@Content_jp=@Content_en,
					@Content_th=@Content_th,
					@Content_ko=@Content_en,
					@Content_vn=@Content_vn,
					@CreatorName='starixIT',
					@IsTest=@IsTest,
					@MsgType=3,
					@IsBatch=0,
					@MsgContentsType=110,
					@Remark=@Site,
					@MessageIDOutput=@MessageId OUTPUT

		--Insert MsgTarget
		EXEC Age_Msg_SetUsrMessage @MessageId=@MessageId,@TargetId=3000,@TargetName='Agent Site'
	END
END
GO