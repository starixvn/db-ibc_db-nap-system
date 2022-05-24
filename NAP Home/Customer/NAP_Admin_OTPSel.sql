/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet,bodbPolicyNetView" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_OTPSel]
	@Username		NVARCHAR(50),
	@System			VARCHAR (10),
	@status			TINYINT,
	@PageIndex		INT,
	@PageSize		INT,
	@TotalRows		INT			= 0	OUTPUT
AS

/*
	Created: 20220517@Winfred
	Task :	NAP OTP Login requried for VPN's users
	DB: DBPOL/NAP_UserControl
	Original:

	Revisions:
	    - 20220517@Winfred: Search OTP Login requried for VPN's users [redmine:170994]
	    
	Param's Explanation:
	• @Username: Username search text
	• @System: ALL = '', NAP, NAP SC
	• @status: Status (0:All, 1:Active, 2:Closed)
*/

BEGIN
	SET NOCOUNT ON    
	DECLARE @FirstRec INT, @LastRec INT
	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1
	SELECT @LastRec = @PageIndex * @PageSize

	CREATE TABLE #Result(
		CustID INT,
		username varchar(30),
		SecretKey NVARCHAR(50),
		IgnoreOTP BIT,
		[System] varchar(10),
		Creator int,
		CreatorName varchar(30),
		[Status] varchar(30),
		[firstname] nvarchar(50),
		RowNumber INT IDENTITY(1,1) NOT NULL
	)

   	-- Update OTP admin
	INSERT INTO #Result(CustID,username,SecretKey,IgnoreOTP,System,Creator,Status,firstname,CreatorName)
	SELECT a.CustID,c.username,a.SecretKey,a.IgnoreOTP,a.System,a.Creator,(CASE WHEN ci.closed  = 0 THEN 'Active' ELSE 'Closed' END) AS [Status],c.firstname,ad.username AS CreatorName
	FROM AdminOTP AS a WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON a.custid = c.custid
		INNER JOIN CustDB.dbo.Custinfo AS ci WITH (NOLOCK) ON a.custid = ci.custid
		INNER JOIN CustDB.dbo.Customer AS ad WITH (NOLOCK) ON c.creator = ad.custid
	WHERE c.username = CASE WHEN ISNULL(@Username,'') <> ''  THEN @Username  ELSE c.username END
	AND a.System = CASE WHEN ISNULL(@System,'') <> ''  THEN @System  ELSE a.System END
	AND (@Status = 0 OR ( ci.closed = CASE WHEN @Status = 1 THEN 0 
										  WHEN @Status = 2 THEN 1 ELSE ci.closed END ))

	SELECT @TotalRows = COUNT(1) FROM #Result

	SELECT * 
	FROM #Result
	WHERE RowNumber BETWEEN @FirstRec AND @LastRec 	

	DROP TABLE #Result
END

