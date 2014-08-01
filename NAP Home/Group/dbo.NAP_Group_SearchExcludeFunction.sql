USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Group_SearchExcludeFunction]    Script Date: 8/1/2014 1:38:03 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Group_SearchExcludeFunction]
    @GroupName       NVARCHAR(50)    
    ,@SiteId        INT
    ,@FunctionId    INT	
AS
/*  
 * Created: 20120820@Edward
 * Task : Search group
 * DB: bodb_NAP
 *  
 * Revisions:
 * Param's Explanation: 
*/
BEGIN

	SET NOCOUNT ON

	-- gets total rows
	SELECT g.GroupId
		,g.GroupName
		,g.Description
		,g.IsActive
		,g.CreatedDate
		,g.ModifiedDate
		,g.CreatedBy	AS CreatorId         
		,ci.Username	AS CreatorUsername       
		,g.ModifiedBy	AS ModifierId
		,ci1.Username	AS ModifierUsername    
	FROM 
		dbo.Groups AS g WITH (NOLOCK)   
		LEFT JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON g.CreatedBy = ci.custid
		LEFT JOIN bodb02.dbo.custInfo AS ci1 WITH (NOLOCK) ON g.ModifiedBy = ci1.custid
	WHERE g.GroupName LIKE '%' + @GroupName + '%'
		AND g.GroupId NOT IN (
			SELECT GroupId 
			FROM GroupFunction WITH (NOLOCK)
			WHERE FunctionId = @FunctionId AND SiteId = @SiteId AND Policy > 0
		)
END

GO
GRANT EXECUTE ON [dbo].[NAP_Group_SearchExcludeFunction] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Group_SearchExcludeFunction] TO [vnteam] AS [dbo]