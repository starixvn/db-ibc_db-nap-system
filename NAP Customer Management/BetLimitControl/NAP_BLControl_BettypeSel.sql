/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_BettypeSel] 
	@ProductList VARCHAR(200) = '0',
	@SporttypeList VARCHAR(MAX) = '0',
	@BetLimitTypeID INT = 0
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - select bettype list 
	DB: DBCUST/CustDB
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:

	Example: 
	EXEC NAP_BLControl_BettypeSel 
		@ProductList = '0',
		@SporttypeList = '0',
		@BetLimitTypeID = 1
	*/
BEGIN
	CREATE TABLE #BTC_SportBettype(
			ProductID TINYINT,
			Sporttype INT, 
			Bettype INT,
			BettypeName NVARCHAR(128)
			PRIMARY KEY (ProductID,Sporttype,Bettype)
	)
	INSERT INTO #BTC_SportBettype(ProductID,Sporttype,Bettype,BettypeName)
	SELECT m.ProductID,m.Sporttype,m.Bettype,MAX(s.typenamee)
	FROM DBEXT.bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN DBPRO.bodb02.dbo.Bettype s WITH(NOLOCK) ON m.Bettype = s.typeid
	WHERE m.ProductID IN (SELECT ProductID FROM BetLimitControlProduct WITH(NOLOCK))
	GROUP BY m.ProductID,m.Sporttype,m.Bettype

	SELECT 	DISTINCT 
		c.Bettype,
		c.BettypeName,
		Selected = ISNULL(bt.Selected,0)
	FROM #BTC_SportBettype c
		CROSS APPLY (SELECT cast (1 as bit) AS Selected FROM dbo.f_StringSplit(@ProductList,',') pr WHERE pr.val = c.ProductID OR pr.val = 0) pro
		CROSS APPLY (SELECT cast (1 as bit) AS Selected FROM dbo.f_StringSplit(@SporttypeList,',') pr WHERE pr.val = c.Sporttype OR pr.val = 0) sp
		OUTER APPLY (	SELECT DISTINCT cast (1 as bit) AS Selected 
						FROM BetLimitControlTypeDetail b WITH(NOLOCK) 
						WHERE (b.Bettype = c.Bettype OR b.Bettype = 0)
							AND BetLimitTypeID = @BetLimitTypeID) bt
	ORDER BY c.Bettype,c.BettypeName
END
GO


