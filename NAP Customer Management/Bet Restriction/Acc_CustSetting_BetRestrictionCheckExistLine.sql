/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCheckExistLine] 
	  @CustID		INT = NULL
	 ,@SportType    TINYINT = 1
AS
/*
	Created: 20190807@Eden
	Task : Check Bet Restriction exists for Upline and Downline
	DB: DBCUST/CustDB
	Original:

	Example: EXEC Acc_CustSetting_BetRestrictionCheckExistLine @CustID = 1176083
		
	*/
BEGIN
	SELECT bc.CustID,
		   up.CustID as ExistingUpline,
		   upCust.username AS ExistingUplineUserName,
		   ISNULL(t.IsDownlineExists,0) AS IsDownlineExists
	FROM BetRestriction_Customer bc WITH(NOLOCK)
		 JOIN custInfo ci WITH(NOLOCK) ON bc.CustID = ci.custid
		 LEFT JOIN BetRestriction_Customer Up WITH(NOLOCK) 
			ON up.CustID = CASE WHEN ci.roleid = 1 THEN ci.recommend
								WHEN ci.roleid = 2 THEN ci.mrecommend
								WHEN ci.roleid = 3 THEN ci.srecommend
						    END
		 LEFT JOIN custInfo upCust WITH(NOLOCK) ON up.CustID = upCust.custid
		 OUTER APPLY (	SELECT TOP 1 1 AS IsDownlineExists 
						FROM BetRestriction_Customer b WITH(NOLOCK) 
							JOIN custInfo ci1 WITH(NOLOCK) ON b.CustID = ci1.custid
						WHERE ci.CustID = CASE WHEN ci.roleid = 4 THEN ci1.srecommend
											   WHEN ci.roleid = 3 THEN ci1.mrecommend
											   WHEN ci.roleid = 2 THEN ci1.recommend 
										END
					 ) t
	WHERE bc.CustID = @CustID AND bc.SportType = @SportType
		  
END
GO


