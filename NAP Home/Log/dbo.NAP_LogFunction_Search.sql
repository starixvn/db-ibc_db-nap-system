USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_LogFunction_Search]    Script Date: 8/1/2014 1:40:03 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_LogFunction_Search]
    @Name			NVARCHAR(50)	= ''
	,@SiteId		INT				= 0
    ,@From			DATETIME
	,@To			DATETIME
	,@PageIndex		INT
	,@PageSize		INT
	,@TotalRows		INT				= 0		OUTPUT	
AS
/*  
 * Created: 20120820@Edward
 * Task : Search log function
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
	SET @TotalRows = (
		SELECT COUNT(1)
		FROM 
			bodb_NAPLog.dbo.NAPLog_Function AS lf WITH (NOLOCK)
			INNER JOIN Users AS u WITH (NOLOCK) ON lf.UserId = u.UserId
			INNER JOIN bodb02.dbo.custInfo AS cu WITH (NOLOCK) ON u.UserId = cu.custid		
			INNER JOIN Functions AS f WITH (NOLOCK) ON lf.FunctionId = f.FunctionId
		WHERE 
			f.FunctionName LIKE '%' + @Name + '%'		
			AND lf.LogDate BETWEEN @From AND @To
			AND (@SiteId = 0 OR (@SiteId !=0 AND lf.SiteId = @SiteId))
	)

	-- gets data
	SELECT TOP (@PageSize) *
	FROM (
			SELECT 
				lf.Id,					
				lf.IP,
				lf.LogDate,										
				lf.BrowserName,			
				lf.Params,
				lf.FunctionId,
				f.FunctionName,
				lf.UserId,
				cu.username,
				lf.SiteId,
				s.SiteName,					
				row_number() OVER (ORDER BY lf.LogDate DESC) AS num
			FROM 
				bodb_NAPLog.dbo.NAPLog_Function AS lf WITH (NOLOCK)
				INNER JOIN Users AS u WITH (NOLOCK) ON lf.UserId = u.UserId
				INNER JOIN bodb02.dbo.custInfo AS cu WITH (NOLOCK) ON u.UserId = cu.custid	
				INNER JOIN Functions AS f WITH (NOLOCK) ON lf.FunctionId = f.FunctionId			
				INNER JOIN Sites AS s WITH (NOLOCK) ON lf.SiteId = s.SiteId
			WHERE 
				f.FunctionName LIKE '%' + @Name + '%'		
				AND lf.LogDate BETWEEN @From AND @To
				AND (@SiteId = 0 OR (@SiteId !=0 AND lf.SiteId = @SiteId))
		) AS Temp
	WHERE
		Temp.num >= @FirstRec
		AND Temp.num <= @LastRec
	ORDER BY
		Temp.num
	
END

GO
GRANT EXECUTE ON [dbo].[NAP_LogFunction_Search] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_LogFunction_Search] TO [vnteam] AS [dbo]