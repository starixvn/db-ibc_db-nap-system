/*<info serverAlias="DBPOL-NAP_UserControl" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_User_SearchByUsername]
	@Username	VARCHAR(30),
	@PageIndex	INT,
	@PageSize	INT,
	@TotalRows	INT			= 0	OUTPUT
AS

/*
	Created: 20120820@Edward
	Task : Search user by username
	DB: DBNAP.bodb_NAP
	Revisions:
		- 20171124@Kos: Return additional column Closed [Redmine: #87124]
		- 20180925@Helen: DB052.bodb_NAP Migration to DBCust - [Redmine:100493]
		- 20241023@Elodie: Enhance SP 
	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FirstRec INT,
		@LastRec INT

	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1
	SELECT @LastRec = ((@PageIndex * @PageSize + 1)) - 1

	-- Gets total rows
	SET @TotalRows = (
		SELECT COUNT(1)
		FROM CustDB.dbo.Customer AS c WITH (NOLOCK)
		WHERE c.roleid > 4
			AND c.username LIKE @Username + '%'
			AND NOT EXISTS (SELECT 1 FROM dbo.NAP_Users WITH (NOLOCK) WHERE UserId = c.custid)
	)

	-- Gets data
	SELECT TOP(@PageSize) *
	FROM (
		SELECT
			c.custid AS UserId,
			c.firstname,
			c.lastname,
			c.username,
			ci.closed,
			ROW_NUMBER() OVER (ORDER BY c.username) AS num
		 FROM CustDB.dbo.Customer AS c WITH (NOLOCK)
			INNER JOIN CustDB.dbo.custInfo AS ci WITH (NOLOCK) ON c.custid = ci.custid
		 WHERE c.roleid > 4
			AND c.username LIKE @Username + '%'
			AND NOT EXISTS (SELECT 1 FROM dbo.NAP_Users WITH (NOLOCK) WHERE UserId = c.custid)
		) AS Temp
	WHERE Temp.num BETWEEN @FirstRec AND @LastRec
	ORDER BY Temp.num
END
GO

