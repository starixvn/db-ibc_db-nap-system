USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_User_SearchByUsername]    Script Date: 8/1/2014 1:52:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_User_SearchByUsername]
	@Username	NVARCHAR(50),
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
		FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
		WHERE c.roleid > 4
			AND c.username LIKE '%' + @Username + '%'
			AND NOT EXISTS (SELECT 1 FROM Users WITH (NOLOCK) WHERE UserId = c.custid)
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
		 FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
			INNER JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON c.custid = ci.custid
		 WHERE c.roleid > 4
			AND c.username LIKE '%' + @Username + '%'
			AND NOT EXISTS (SELECT 1 FROM Users WITH (NOLOCK) WHERE UserId = c.custid)
		) AS Temp
	WHERE Temp.num BETWEEN @FirstRec AND @LastRec
	ORDER BY Temp.num
END

GO
GRANT EXECUTE ON [dbo].[NAP_User_SearchByUsername] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_SearchByUsername] TO [vnteam] AS [dbo]
GO
