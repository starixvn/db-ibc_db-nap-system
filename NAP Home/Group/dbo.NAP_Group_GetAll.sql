USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Group_GetAll]    Script Date: 8/1/2014 1:36:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--EXEC NAP_Group_GetAll

ALTER PROCEDURE [dbo].[NAP_Group_GetAll]
    @IsActive	BIT	= NULL 
AS

/*  
 * Created: 20120810@Edward
 * Task : Get all group
 * DB: bodb_NAP
 *  
 * Revisions:     
 * Param's Explanation: 
*/

BEGIN
    SET NOCOUNT ON    
     
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
    FROM dbo.Groups AS g WITH (NOLOCK)   
    LEFT JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON g.CreatedBy = ci.custid
	LEFT JOIN bodb02.dbo.custInfo AS ci1 WITH (NOLOCK) ON g.ModifiedBy = ci1.custid
    WHERE (@IsActive IS NULL OR (@IsActive IS NOT NULL AND g.IsActive = @IsActive))
	
END

GO
GRANT EXECUTE ON [dbo].[NAP_Group_GetAll] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Group_GetAll] TO [vnteam] AS [dbo]