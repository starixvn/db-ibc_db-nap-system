/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BLControl_SportBettypeSel] 
AS
/*
	Created: 20200525@Eden
	Task : Bet Limit Control - select Sport bettype matrix use Betlimit control function 
	DB: DBACC-bodb02
	Original:

	Revisions:  
	- 20200525@Eden: Create New SP  [RedmineID: #132736]

	Parameter explanation:

	Example: 
	EXEC NAP_BLControl_SportBettypeSel 
	*/
BEGIN
	SELECT c.ProductID, 
		p.ProductName
	FROM BetLimitControlProduct c WITH(NOLOCK) 
		INNER JOIN dbo.products p WITH(NOLOCK) ON c.ProductID = p.ProductID
	ORDER BY c.ProductID
	
	SELECT DISTINCT m.ProductID,m.Sporttype,SportName
	FROM dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN dbo.sports s WITH(NOLOCK) ON m.Sporttype = s.Sporttype
	WHERE m.ProductID IN (SELECT ProductID FROM BetLimitControlProduct WITH(NOLOCK))

	SELECT DISTINCT m.ProductID,m.Sporttype,m.Bettype,s.typenamee AS BettypeName
	FROM dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN dbo.sports sp WITH(NOLOCK) ON m.Sporttype = sp.Sporttype
		INNER JOIN dbo.Bettype s WITH(NOLOCK) ON m.Bettype = s.typeid
	WHERE m.ProductID IN (SELECT ProductID FROM BetLimitControlProduct WITH(NOLOCK))
END
GO


