/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_GlobalStakeLevelGroup_ProductSel] 
	-- Add the parameters for the stored procedure here
	  @pMutilProductID	VARCHAR(MAX) = '0'
	  ,@IsCredit		BIT=1
AS
/*
	Created: 20230914@Tacy
	Task : 3rd Products - Simplify RNG Games bet limit setting
	DB: DBACC/bodb02

	Revisions:
		- 20230914@Tacy: Create SP [Redmine: #194332]
		- 20240624@Tacy: Implement more function [Redmine: #196256]

	Param's Explanation:
		@pMutilProductID  0 : All, <> 0 : ProductID
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #SportProfile(
			[SportType] [smallint],
			[ProductID] [tinyint],
			PRIMARY KEY([SportType] ASC,[ProductID] ASC)
		)

	CREATE TABLE #Products(ProductID TINYINT PRIMARY KEY, ProductName VARCHAR(50))
	
	INSERT INTO #Products  (ProductID,ProductName)	
	SELECT ProductID,ProductName 
	FROM dbo.products WITH(NOLOCK)
	WHERE (@pMutilProductID = '0' OR ProductID IN (SELECT TRIM(value) val FROM STRING_SPLIT(@pMutilProductID, ',')))
		AND Enabled=1
	
	IF @IsCredit=1
	BEGIN
		INSERT INTO #SportProfile(SportType,ProductID)
		SELECT DISTINCT p.SportType,s.ProductID 
		FROM ProductStakeLevelGroup P WITH (NOLOCK) 
		CROSS APPLY (SELECT TOP 1 RealProductId AS ProductID
					 FROM SportBettypeSettingMatrix sm WITH (NOLOCK)
					 WHERE p.SportType=sm.SportTypeRefBetSetting AND isLicensee=0 
						AND sm.isDeleted=0 AND isActive=1) s
		WHERE p.isDeleted=0
	END
	ELSE
	BEGIN
		INSERT INTO #SportProfile(SportType,ProductID)
		SELECT DISTINCT p.SportType,s.ProductID
		FROM Dep_ProductStakeLevelGroup P WITH (NOLOCK) 
		CROSS APPLY (SELECT TOP 1 RealProductId AS ProductID
					 FROM SportBettypeSettingMatrix sm WITH (NOLOCK)
					 WHERE p.SportType=sm.SportTypeRefBetSetting AND isLicensee=1 
						AND sm.isDeleted=0 AND isActive=1) s
		WHERE p.isDeleted=0
	END
   
	SELECT p.ProductID, p.ProductName
	FROM #SportProfile s WITH(NOLOCK)
	INNER JOIN #Products p WITH(NOLOCK) ON s.ProductID = p.ProductID
	ORDER BY ProductID 

	DROP TABLE #Products, #SportProfile
END
GO