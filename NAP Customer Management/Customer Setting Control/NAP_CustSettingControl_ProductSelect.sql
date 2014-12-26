ALTER PROCEDURE [dbo].[NAP_CustSettingControl_ProductSelect]
AS 
/*	Created by: Dominic
	Date: 20141225
	Task: Get products that support PT Policy (SB,RB,NG,LC,VS,KN)
	DB: DBACC/bodb02
	*Revisions:
		
*/
BEGIN	
	SELECT ProductID
		, ProductName
		, ProductPrefix
	FROM dbo.Products WITH (NOLOCK)
	WHERE ProductID IN (1, 2, 3, 4, 5, 8)
	ORDER BY ProductID
END
