ALTER PROCEDURE [dbo].[NAP_CustSettingControl_PTPolicySelect]
	@SiteID				INT			= NULL,
	@Currency			INT			= NULL,
	@RoleID				TINYINT		= NULL
AS 
/*	Created by: Dominic
	Date: 20141225
	Task: Display PT Policy for Products
	DB: DBACC/bodb02
	*Parameters:

	*Revisions:
		
*/
BEGIN	
	SELECT 
		s.SiteID
		,s.Site
		,e.ExchangeID
		,e.Currency
		,p.RoleID
		,p.ProductID
		,p.SuperMax
		,p.MasterMax
		,p.AgentMax
	FROM dbo.PTSettingPolicy p WITH(NOLOCK)
	JOIN dbo.Site s WITH(NOLOCK) ON s.SiteID=p.SiteID
	JOIN dbo.Exchange e WITH(NOLOCK) ON e.ExchangeID=p.ExchangeID
	WHERE (@SiteID IS NULL OR p.SiteID = @SiteID)
			AND 
			(@Currency IS NULL OR p.ExchangeID = @Currency)
			AND 
			(@RoleID IS NULL OR p.RoleID = @RoleID) 
	ORDER BY SiteID,ExchangeID,RoleID,ProductID
END
