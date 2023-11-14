/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROC [dbo].[NAP_Domain_Del]
	 @DomainID		SMALLINT
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

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	IF ISNULL(@DomainID,0)=0
		RETURN
	
	DECLARE @StartRun DATETIME, @EndRun DATETIME, @Duration INT, @logSpData NVARCHAR(MAX)

	SET @StartRun = GETDATE()	

	IF NOT EXISTS (SELECT TOP 1 1 FROM DomainManagement d WITH (NOLOCK)
				WHERE d.DomainID=@DomainID AND d.isDeleted=0)
	BEGIN
		SET @ErrCode=100
		SET @ErrMsg='This domain is not available'
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
		WHERE d.DomainID=@DomainID AND d.isDeleted=0
		FOR XML RAW ('Domain'), ROOT('DomainList'))

	BEGIN TRY
		UPDATE d
		SET d.isDeleted=1
			,d.RepUpdateTime=SYSDATETIME()
		FROM DomainManagement d  WITH (ROWLOCK,UPDLOCK)
		WHERE d.isDeleted=0 AND d.DomainID=@DomainID
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