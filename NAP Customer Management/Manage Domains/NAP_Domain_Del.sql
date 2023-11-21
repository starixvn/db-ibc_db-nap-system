/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROC [dbo].[NAP_Domain_Del]
	 @DomainList	NVARCHAR(MAX)
	,@UserID		INT
	,@IP			VARCHAR(50)	= ''
	,@ErrCode		INT=0			 OUTPUT
	,@ErrMsg		VARCHAR(2000)='' OUTPUT
AS
/*
	Created: 20231013@Tacy
	Task: Delete domain
	DB: DBCUST-CUSTDB
	
	Revisions:
		- 20231013@Tacy: NAP CM - Manage Domain [RedmineID: #194024]
		- 20231116@Tacy: Support delete multiple domains [RedmineID: #194024]

	Param's Explanation:
		@DomainList:
				<DomainList>
						<Domain id="1" d="alpha01.com" />
						<Domain id="2" d="alpha02.com" />
				</DomainList>
*/
BEGIN
	SET NOCOUNT ON;
	
	IF ISNULL(@DomainList,'')=''
		RETURN
	
	CREATE TABLE #tbDomains (DomainID SMALLINT PRIMARY KEY, Domain	VARCHAR(50))

	DECLARE @XML XML, @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @logSpData NVARCHAR(MAX)

	SET @StartRun = GETDATE()	

	SELECT @XML=CAST(@DomainList AS xml)

	INSERT INTO #tbDomains (DomainID, Domain)
	SELECT t.s.value('@id','SMALLINT') AS Domain
		, t.s.value('@d','VARCHAR(50)') AS Domain
	FROM @xml.nodes('DomainList/Domain') t(s)

	IF EXISTS (SELECT TOP 1 1 FROM #tbDomains t
				LEFT JOIN DomainManagement d WITH (NOLOCK)
								ON d.DomainID=t.DomainID AND d.isDeleted=0
				WHERE d.DomainID IS NULL)
	BEGIN
		SELECT TOP 1 
				@ErrCode=100
				,@ErrMsg='The ' + t.Domain + ' is not available'
		FROM #tbDomains t
		LEFT JOIN DomainManagement d WITH (NOLOCK)
						ON d.DomainID=t.DomainID AND d.isDeleted=0
		WHERE d.DomainID IS NULL

		RETURN
	END

	SELECT @logSpData = (
		SELECT d.DomainID	AS 'id'
			, d.Domain		AS 'd'
			, d.System		AS 'ss'
			, d.Site		AS 's'
			, d.Status		AS 'stt'
			, d.ExpiredDate	AS 'ed'
			, COALESCE (d.RestrictedCountries,'')	AS 'c'
			, COALESCE (d.Remark,'')				AS 'r'
			, COALESCE (d.BrandName,'')				AS 'b'
		FROM DomainManagement d WITH (NOLOCK) 
		INNER JOIN #tbDomains t ON d.DomainID=t.DomainID AND d.isDeleted=0
		FOR XML RAW ('Domain'), ROOT('DomainList'))

	BEGIN TRY
		UPDATE d
		SET d.isDeleted=1
			,d.RepUpdateTime=SYSDATETIME()
		FROM DomainManagement d  WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #tbDomains t ON d.DomainID=t.DomainID AND d.isDeleted=0
	END TRY
	BEGIN CATCH
		SELECT  @ErrCode = ERROR_NUMBER(),@ErrMsg = ERROR_MESSAGE();		
		RETURN
	END CATCH

	--Write log
	SELECT @EndRun	= GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

	DECLARE @NewLog VARCHAR(MAX)
	SET @NewLog = '<DomainList IP="'+ COALESCE(CAST(@IP AS VARCHAR(15)),'')+'" >'
	
	SELECT @logSpData = REPLACE(@logSpData, '<DomainList>', @NewLog)

	EXEC  Acc_WriteLog_UserLog_RunSP_Wrapper
				@UserID = @UserID,
				@ActionID = 31775,
				@TrackingValue = @LogSPData,
				@duration = @Duration
END
GO