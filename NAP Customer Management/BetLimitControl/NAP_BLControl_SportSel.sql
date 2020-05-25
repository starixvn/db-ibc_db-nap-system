/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_SportSel] 
	@ProductList VARCHAR(200) = '0',
	@BetLimitTypeID INT = 0
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - select Sport list 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:

	Example: 
	EXEC NAP_BLControl_SportSel 
		@ProductList = '0',
		@BetLimitTypeID = 1
	*/
BEGIN
	CREATE TABLE #BTC_Sport(
			ProductID TINYINT,
			Sporttype INT, 
			SportName NVARCHAR(50)
			PRIMARY KEY (ProductID,Sporttype)
	)
	INSERT INTO #BTC_Sport(ProductID,Sporttype,SportName)
	SELECT m.ProductID,m.Sporttype,MAX(SportName)
	FROM DBEXT.bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN DBPRO.bodb02.dbo.sports s WITH(NOLOCK) ON m.Sporttype = s.Sporttype
	WHERE m.ProductID IN (SELECT ProductID FROM BetLimitControlProduct WITH(NOLOCK))
	GROUP BY m.ProductID,m.Sporttype

	SELECT c.Sporttype,
		Sportname,
		Selected = ISNULL(sp.Selected,0)
	FROM #BTC_Sport c
		CROSS APPLY (SELECT cast (1 as bit) AS Selected  FROM dbo.f_StringSplit(@ProductList,',') pr WHERE pr.val = c.ProductID OR pr.val = 0) pro
		OUTER APPLY (	SELECT DISTINCT cast (1 as bit) AS Selected 
						FROM BetLimitControlTypeDetail b WITH(NOLOCK) 
						WHERE (b.Sporttype = c.Sporttype OR b.Sporttype = 0)
							AND BetLimitTypeID = @BetLimitTypeID) sp
	ORDER BY c.Sporttype  
END
GO


