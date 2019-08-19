/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CheckExistLine] 
	  @CustID		INT = NULL
	 ,@SportType    TINYINT = 1
AS
/*
	Created: 20190815@Eden
	Task : Check Bet Restriction exists for Upline and Downline when insert new
	DB: DBACC/bodb02
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP [RedmineID: #117727]

	Example: EXEC NAP_BetRestriction_CheckExistLine @CustID = 1752427, @SportType = 1
		
	*/
BEGIN
	SELECT ci.CustID,
		   up.CustID as ExistingUpline,
		   upCust.username AS ExistingUplineUserName,
		   --up.SeizeBetTicket AS Upline_SeizeBetTicket,
		   ISNULL(down.IsDownlineExists,0) AS IsDownlineExists
	FROM custInfo ci WITH(NOLOCK) 
		 LEFT JOIN BetRestriction_Customer Up WITH(NOLOCK) 
			ON up.CustID = CASE WHEN ci.roleid = 1 THEN ci.recommend
								WHEN ci.roleid = 2 THEN ci.mrecommend
								WHEN ci.roleid = 3 THEN ci.srecommend
						    END
			AND up.SportType = @SportType
		 LEFT JOIN custInfo upCust WITH(NOLOCK) ON up.CustID = upCust.custid
		 OUTER APPLY (	SELECT TOP 1 1 AS IsDownlineExists 
						FROM BetRestriction_Customer b WITH(NOLOCK) 
							JOIN custInfo ci1 WITH(NOLOCK) ON b.CustID = ci1.custid
						WHERE ci.CustID = CASE WHEN ci.roleid = 4 THEN ci1.srecommend
											   WHEN ci.roleid = 3 THEN ci1.mrecommend
											   WHEN ci.roleid = 2 THEN ci1.recommend 
										END
							AND b.SportType = @SportType
					 ) down
	WHERE ci.CustID = @CustID 
		  
END
GO


