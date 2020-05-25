/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_ProductSel] 
	  @BetLimitTypeID INT = 0
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - select Product list 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:

	Example: 
	EXEC NAP_BLControl_ProductSel 
		@BetLimitTypeID = 1
	*/
BEGIN
	SELECT c.ProductID, 
		p.ProductName,
		Selected = ISNULL(pro.Selected,0)  
	FROM BetLimitControlProduct c WITH(NOLOCK) 
		INNER JOIN DBPRO.bodb02.dbo.products p WITH(NOLOCK) ON c.ProductID = p.ProductID
		OUTER APPLY (	SELECT DISTINCT cast (1 as bit) AS Selected 
						FROM BetLimitControlTypeDetail b WITH(NOLOCK) 
						WHERE (b.ProductID = c.ProductID OR b.ProductID = 0)
							AND BetLimitTypeID = @BetLimitTypeID) pro
	ORDER BY c.ProductID	  
END
GO


