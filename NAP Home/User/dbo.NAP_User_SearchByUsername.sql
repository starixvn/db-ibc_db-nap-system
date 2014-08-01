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
	@TotalRows	INT	= 0	OUTPUT
AS

/*  
 * Created: 20120820@Edward
 * Task : Search user by username
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/

BEGIN

	DECLARE @FirstRec INT, @LastRec INT
	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1
	SELECT @LastRec = ((@PageIndex * @PageSize + 1)) - 1

	SET NOCOUNT ON

	-- gets total rows
	SET @TotalRows = (SELECT COUNT(1)
					  FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
					  WHERE roleid > 4
						  and c.username LIKE '%' + @Username + '%'
						  AND c.custid NOT IN (SELECT UserId FROM Users WITH (NOLOCK)))

	-- gets data
	SELECT TOP (@PageSize) *
	FROM
		(SELECT 
			c.custid AS UserId, 
			c.firstname, 
			c.lastname, 
			c.username, 
			row_number() OVER (ORDER BY c.username) AS num
		 FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
		 WHERE roleid > 4						  
			 and c.username LIKE '%' + @Username + '%'
			 AND c.custid NOT IN (SELECT UserId FROM Users WITH (NOLOCK))) AS Temp
	WHERE
		Temp.num >= @FirstRec
		AND Temp.num <= @LastRec

END

GO
GRANT EXECUTE ON [dbo].[NAP_User_SearchByUsername] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_User_SearchByUsername] TO [vnteam] AS [dbo]