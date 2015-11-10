USE [bodb02]
GO

/****** Object:  UserDefinedFunction [dbo].[f_GroupBettype]    Script Date: 11/12/2015 10:29:21 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/****** Object:  User Defined Function dbo.f_GroupBettype    Script Date: 4/27/2015 10:34:40 AM ******/
ALTER FUNCTION [dbo].[f_ProductPayout] ()
RETURNS @ProductPayout TABLE (ProductId TINYINT, SportType SMALLINT, ProductName VARCHAR(30), SportName VARCHAR(30))
AS 
/*
	Created: 20151112@SBobby
	Task :	#47290 - Colossus Bets & MCG RnG Casino Payout Management
	DB:		DBEXT.bodb02
 	Revisions: 

*/

BEGIN 

	INSERT INTO @ProductPayout (
		ProductId
		, SportType
		, ProductName
		, SportName
	)
	SELECT DISTINCT p.ProductId
		, s.SportType
		, p.ProductName
		, s.SportName
	FROM dbo.Products p WITH(NOLOCK)
		INNER JOIN dbo.SportBettypeMatrix sp WITH(NOLOCK)
		ON p.ProductId = sp.ProductId
		INNER JOIN dbo.Sports s WITH(NOLOCK)
		ON sp.SportType = s.SportType
	WHERE p.ProductId IN (15, 17)

	
	RETURN
END
GO