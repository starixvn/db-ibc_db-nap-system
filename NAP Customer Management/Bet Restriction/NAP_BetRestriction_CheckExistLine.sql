/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_CheckExistLine] 
	  @Username		NVARCHAR(50) 
	 ,@SportType    TINYINT = 1
AS
/*
	Created: 20190815@Eden
	Task : Check Bet Restriction exists for Upline and Downline when insert new
	DB: DBACC/bodb02
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP [RedmineID: #117727]
	- 20230313@Helios: Remove Check and Alert SeiBetTicket for Sport Soccer and Basketball. Approve Check and Alert for Soccer and Badminton FROM Basketball Code [RedmineID: #183662]

	Example: EXEC NAP_BetRestriction_CheckExistLine @Username = 'master1', @SportType = 1
		
	*/
BEGIN
	DECLARE @CustID INT

	SELECT @CustID = CustID FROM custinfo WITH(NOLOCK) WHERE username = @Username

	IF @SportType = 1
	BEGIN
		SELECT ci.CustID,
			   CAST(CASE WHEN upCust.CustID IS NOT NULL THEN 1 ELSE 0 END AS BIT ) AS IsUplineExists,
			   UplineLevel = CASE WHEN upCust.roleid = 2 THEN 'Agent'
							  WHEN upCust.roleid = 3 THEN 'Master'
							  WHEN upCust.roleid = 4 THEN 'Super'
						END,
			   upCust.username AS ExistingUplineUserName,
			   --Upline_SeizeBetTicket = COALESCE(Aup.SeizeBetTicket,MUp.SeizeBetTicket,SUp.SeizeBetTicket,bcu.SeizeBetTicket,bs.SeizeBetTicket),    --  [RedmineID: #183662]
			   CAST(CASE WHEN down.ExistingDownLine IS NOT NULL THEN 1 ELSE 0 END AS BIT ) IsDownlineExists
			   --down.Min_Downline_SeizeBetTicket                                                                                                    --  [RedmineID: #183662]
		FROM customer ci WITH(NOLOCK) 
			 LEFT JOIN BetRestriction_Customer AUp WITH(NOLOCK) 
				ON AUp.CustID = ci.recommend AND AUp.SportType = @SportType AND ci.CustID  <> ci.recommend
			 LEFT JOIN BetRestriction_Customer MUp WITH(NOLOCK) 
				ON MUp.CustID = ci.mrecommend AND MUp.SportType = @SportType AND ci.CustID  <> ci.mrecommend
			 LEFT JOIN BetRestriction_Customer SUp WITH(NOLOCK) 
				ON SUp.CustID = ci.srecommend AND SUp.SportType = @SportType AND ci.CustID  <> ci.srecommend
			 LEFT JOIN custInfo upCust WITH(NOLOCK) ON COALESCE(Aup.CustID,MUp.CustID,SUp.CustID) = upCust.custid
			 LEFT JOIN Site s WITH(NOLOCK) ON s.site = ci.site
			 LEFT JOIN Customer Agent WITH(NOLOCK) ON agent.custid = ci.recommend
			 LEFT JOIN Site AgentSite WITH(NOLOCK) ON AgentSite.site = agent.site
			 LEFT JOIN BetRestriction_Site  bs WITH(NOLOCK) ON bs.SiteID = ISNULL(s.SiteID,AgentSite.siteid)
			 LEFT JOIN BetRestriction_Currency bcu WITH(NOLOCK) ON ci.currency = bcu.ExchangeID
				  AND 1 = CASE WHEN ISNULL(s.isLicensee,AgentSite.isLicensee) = 0 AND  bcu.Type IN (0, 1) THEN 1 
							  WHEN ISNULL(s.isLicensee,AgentSite.isLicensee) = 1 AND  bcu.Type IN (0, 2) THEN 1
						  ELSE 0 END
			 OUTER APPLY (	SELECT MIN(NULLIF(b.SeizeBetTicket,0)) AS Min_Downline_SeizeBetTicket  , MIN(b.CustID) AS ExistingDownLine
							FROM BetRestriction_Customer b WITH(NOLOCK) 
								JOIN custInfo ci1 WITH(NOLOCK) ON b.CustID = ci1.custid
							WHERE ci.CustID = CASE WHEN ci.roleid = 4 THEN ci1.srecommend  
												   WHEN ci.roleid = 3 THEN ci1.mrecommend
												   WHEN ci.roleid = 2 THEN ci1.recommend 
											END
								AND b.SportType = @SportType
								AND ci1.custid <> CASE WHEN ci.roleid = 4 THEN ci1.srecommend
												   WHEN ci.roleid = 3 THEN ci1.mrecommend
												   WHEN ci.roleid = 2 THEN ci1.recommend 
											END
						 ) down
		WHERE ci.custid = @CustID
	END
	ELSE-- IF @SportType = 2 else Run Sport 2 or 5 or 9 --  [RedmineID: #183662]
	BEGIN
		SELECT ci.CustID,
			   CAST(CASE WHEN upCust.CustID IS NOT NULL THEN 1 ELSE 0 END AS BIT ) AS IsUplineExists,
			   UplineLevel = CASE WHEN upCust.roleid = 2 THEN 'Agent'
							  WHEN upCust.roleid = 3 THEN 'Master'
							  WHEN upCust.roleid = 4 THEN 'Super'
						END,
			   upCust.username AS ExistingUplineUserName,
			   --Upline_SeizeBetTicket = COALESCE(Aup.SeizeBetTicket,MUp.SeizeBetTicket,SUp.SeizeBetTicket),				--  [RedmineID: #183662]
			   CAST(CASE WHEN down.ExistingDownLine IS NOT NULL THEN 1 ELSE 0 END AS BIT ) IsDownlineExists
			   --,down.Min_Downline_SeizeBetTicket																			--  [RedmineID: #183662]
		FROM customer ci WITH(NOLOCK) 
			 LEFT JOIN BetRestriction_Customer AUp WITH(NOLOCK) 
				ON AUp.CustID = ci.recommend AND AUp.SportType = @SportType AND ci.CustID  <> ci.recommend
			 LEFT JOIN BetRestriction_Customer MUp WITH(NOLOCK) 
				ON MUp.CustID = ci.mrecommend AND MUp.SportType = @SportType AND ci.CustID  <> ci.mrecommend
			 LEFT JOIN BetRestriction_Customer SUp WITH(NOLOCK) 
				ON SUp.CustID = ci.srecommend AND SUp.SportType = @SportType AND ci.CustID  <> ci.srecommend
			 LEFT JOIN custInfo upCust WITH(NOLOCK) ON COALESCE(Aup.CustID,MUp.CustID,SUp.CustID) = upCust.custid
			 LEFT JOIN Customer Agent WITH(NOLOCK) ON agent.custid = ci.recommend
			 OUTER APPLY (	SELECT MIN(NULLIF(b.SeizeBetTicket,0)) AS Min_Downline_SeizeBetTicket  , MIN(b.CustID) AS ExistingDownLine
							FROM BetRestriction_Customer b WITH(NOLOCK) 
								JOIN custInfo ci1 WITH(NOLOCK) ON b.CustID = ci1.custid
							WHERE ci.CustID = CASE WHEN ci.roleid = 4 THEN ci1.srecommend  
												   WHEN ci.roleid = 3 THEN ci1.mrecommend
												   WHEN ci.roleid = 2 THEN ci1.recommend 
											END
								AND b.SportType = @SportType
								AND ci1.custid <> CASE WHEN ci.roleid = 4 THEN ci1.srecommend
												   WHEN ci.roleid = 3 THEN ci1.mrecommend
												   WHEN ci.roleid = 2 THEN ci1.recommend 
											END
						 ) down
		WHERE ci.custid = @CustID
	END
END
GO


