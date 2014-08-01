USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Site_GetByUser]    Script Date: 8/1/2014 1:42:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--EXEC [NAP_Site_GetByUser] 7771656,'UAT'

ALTER PROCEDURE [dbo].[NAP_Site_GetByUser]
    @UserId			INT
    ,@Environment	VARCHAR(10) = 'UAT' --There are two values : UAT and LIVE
    ,@IsActive		BIT			= NULL
AS
/*  
 * Created	: 20120809@Edward
 * Task		: Get site by user id
 * DB		: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/
BEGIN
    SET NOCOUNT ON    
    
    SELECT us.Level
		,us.IsActive
		,us.LastLoginDate
		,us.CreatedDate
		,us.ModifiedDate		
		,us.SiteId
		,s.SiteName	
		,s.URL
		,s.TestURL
		,ci.custid		AS CreatorId
		,ci.username	AS CreatorUsername
		,ci1.custid		AS ModifierId
		,ci1.username ModifierUsername
	FROM 
		dbo.UserSite us  WITH (NOLOCK)
		INNER JOIN dbo.Sites s WITH (NOLOCK) ON us.SiteId = s.SiteId
		LEFT JOIN bodb02.dbo.custInfo ci WITH (NOLOCK) ON us.CreatedBy = ci.custid
		LEFT JOIN bodb02.dbo.custInfo ci1 WITH (NOLOCK) ON us.ModifiedBy = ci1.custid
	WHERE 
		us.UserId = @UserId
		AND (@Environment = 'UAT' OR (@Environment != 'UAT' AND s.Environment = @Environment))
		AND (@IsActive IS NULL OR (@IsActive IS NOT NULL AND us.IsActive = @IsActive))
		AND s.IsActive = 1
	
END

GO
GRANT EXECUTE ON [dbo].[NAP_Site_GetByUser] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Site_GetByUser] TO [vnteam] AS [dbo]