USE [bodb_NAP]
GO
/****** Object:  StoredProcedure [dbo].[Task_NAP_SyncUserFunction]    Script Date: 10/31/2016 22:08:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_NAP_SyncUserFunction]    
AS    

/*      
 * Created : 20130523@Kos    
 * Task  : Import user function and permission from NAP to Accounting    
 * DB  : DBNAP/bodb_NAP    
 *      
 * Revisions:    
 *		20130819@Kos	: Add Special Delete functions
 *		20130829@Kos	: Add Total SMA and Member Active function
 *		20140326@Kos	: Add Customer Management functions
 *		20140408@Kos	: Add Settlement functions
 *		20140526@Kos	: Add NAP CM (Control Turnover) functions
 *		20140530@Kos	: Add NAP CM (Loss Control) functions and NAP Acc Report (Smart Punter)
 *		20140604@Kos	: Add NAP CM (Manage Robots) functions
 *		20140617@Kos	: Add NAP CRM functions
 *		20140701@Kos	: Active user site which have permission on Settlement
 *		20140714@Kos	: Add NAP CM (Manage Smart Punter) functions
 *		20140715@Kos	: Add NAP Acc Report (Keno Win Loss, Total Credit Accounts Enabled/Disabled per Product) functions
 *		20141001@Kos	: Add NAP Special Delete (Void By Bet ID, Void Unsettled Tickets, Void Settled Tickets) functions
 *		20141015@Kos	: Add NAP IMS (LicenseeSettlement, Report, CreateInvoice, Invoice) functions
 *		20141021@Kos	: Add NAP Acc Report (AG Casino Win Loss) functions
 *		20141028@Dan	: Add Daily WinLoss (2h) Soccer Minor Bettype functions
 *		20141118@Dan	: Add Customer Management functions
 *		20151210@Dan	: Stop synch for Invoice site
 * Param's Explanation:      
 */    

BEGIN    

	SET NOCOUNT ON    

	DECLARE @AccountingReportSiteId		TINYINT    
	DECLARE @SpecialDeleteSiteId		TINYINT    
	DECLARE @CustomerManagementSiteId	TINYINT    
	DECLARE @SettlementSiteId			TINYINT    
	DECLARE @CRMSiteId					TINYINT    
	DECLARE @IMSSiteId					TINYINT    

	--SET @AccountingReportSiteId = 3    -- Local
	SET @AccountingReportSiteId = 4    -- Production

	--SET @SpecialDeleteSiteId = 70    -- Local
	SET @SpecialDeleteSiteId = 16    -- Production

	--SET @CustomerManagementSiteId = 84    -- Local
	SET @CustomerManagementSiteId = 20    -- Production

	--SET @SettlementSiteId = 67    -- Local
	SET @SettlementSiteId = 18    -- Production

	--SET @CRMSiteId = 83    -- Local
	SET @CRMSiteId = 19    -- Production

	--SET @IMSSiteId = 73    -- Local
	SET @IMSSiteId = 14    -- Production

	DECLARE @GroupMappingTable TABLE (    
		NAPGroupId			SMALLINT,    
		AccountingGroupId	INT)   

	INSERT INTO @GroupMappingTable (NAPGroupId, AccountingGroupId)    
	SELECT 2, 1  UNION ALL -- IT    
	SELECT 3, 2  UNION ALL -- Management    
	SELECT 6, 3  UNION ALL -- CSD    
	SELECT 9, 4  UNION ALL -- Finance    
	SELECT 19, 127 UNION ALL -- ABD    
	SELECT 10, 115 UNION ALL -- CSD2    
	SELECT 11, 135 UNION ALL -- Horse Racing    
	SELECT 13, 133 UNION ALL -- LG    
	SELECT 4, 112 UNION ALL -- Operation    
	SELECT 12, 114 UNION ALL -- Other Sports    
	SELECT 15, 111 UNION ALL -- Settlement    
	SELECT 16, 125 UNION ALL -- Unit 3    
	SELECT 17, 116 UNION ALL -- Unit 5    
	SELECT 7, 110 UNION ALL -- VIP     
	SELECT 18, 5 UNION ALL -- None    
	SELECT 14, 121    -- RnD    

	-- Begin Accounting Report

	-- Data preparation    

	DECLARE @FunctionMappingTable TABLE (    
		NAPFunctionId			INT,    
		AccountingFunctionId	INT)    

	----  Local test    

	--INSERT INTO @FunctionMappingTable (NAPFunctionId, AccountingFunctionId)    
	--SELECT 36, 125  UNION ALL -- Report Main    
	--SELECT 344, 14  UNION ALL -- Match Win Loss (2a)     
	--SELECT 348, 16  UNION ALL -- WinLoss Summary    
	--SELECT 345, 17  UNION ALL -- Daily Win Loss (2h)    
	--SELECT 347, 34  UNION ALL -- Daily Win Loss (2h) Soccer    
	--SELECT 346, 35  UNION ALL -- Daily Win Loss (2h) Other Sports   
	--SELECT 351, 128 UNION ALL -- Direct balance    
	--SELECT 350, 127 UNION ALL    -- Balance Report   
	--SELECT 1000, 296 UNION ALL -- Invoice Management System    
	--SELECT 1001, 296 UNION ALL -- Settlement Report    
	--SELECT 1002, 296		   -- Create Invoice   
	    
	-- INSERT INTO @GroupMappingTable (NAPGroupId, AccountingGroupId)    
	-- SELECT 23, 110  UNION ALL -- VIP    
	-- SELECT 27, 4     -- Finance    

	-- Production    

	INSERT INTO @FunctionMappingTable (NAPFunctionId, AccountingFunctionId)    
	SELECT 652, 14  UNION ALL -- Match Win Loss (2a)     
	SELECT 653, 16  UNION ALL -- WinLoss Summary    
	SELECT 654, 17  UNION ALL -- Daily Win Loss (2h)    
	SELECT 655, 268  UNION ALL -- Daily Win Loss (2h) Soccer    
	SELECT 656, 267  UNION ALL -- Daily Win Loss (2h) Other Sports  
	SELECT 919, 337  UNION ALL -- "Daily WinLoss (2h) Soccer Minor Bettype
	SELECT 657, 18  UNION ALL -- Trader Performance    
	SELECT 658, 266  UNION ALL -- Trader Performance Soccer    
	SELECT 659, 265  UNION ALL -- Trader Performance Other Sports    
	SELECT 660, 126  UNION ALL -- Report Credit Term    
	SELECT 649, 128  UNION ALL -- Direct Balance    
	SELECT 649, 129  UNION ALL -- Direct Balance    
	SELECT 662, 130  UNION ALL -- Super Balance    
	SELECT 661, 176  UNION ALL -- Company Balance Difference    
	SELECT 664, 133  UNION ALL -- Match Win Loss Single Bet    
	SELECT 665, 132  UNION ALL -- Tree Win Loss    
	SELECT 666, 134  UNION ALL -- Match Win Loss By Bet Type    
	SELECT 667, 135  UNION ALL -- League Win Loss    
	SELECT 668, 280  UNION ALL -- Daily Mix Parlay Win Loss    
	SELECT 669, 136  UNION ALL -- All Customer Turnover (by Site)    
	SELECT 496, 166  UNION ALL -- Peak Concurrent Users    
	SELECT 493, 177  UNION ALL -- Total Transactions By Licensee    
	SELECT 852, 315  UNION ALL -- Playtech Casino Win Loss
	SELECT 494, 185  UNION ALL -- Negative Balance    
	SELECT 498, 188  UNION ALL -- Win Loss By Licensee    
	SELECT 869, 329  UNION ALL -- Keno Win Loss    
	SELECT 900, 336  UNION ALL -- AG Casino Win Loss
	SELECT 495, 276  UNION ALL -- Number Game Win Loss By Licensee    
	SELECT 483, 279  UNION ALL -- Live Casino Win Loss By Licensee    
	SELECT 497, 281  UNION ALL -- Virtual Sports Win Loss By Licensee    
	SELECT 670, 285  UNION ALL -- RNG Casino Win Loss    
	SELECT 672, 37  UNION ALL -- Casino Win Loss    
	SELECT 673, 262  UNION ALL -- Live Casino Agency Win Loss    
	SELECT 674, 289  UNION ALL -- Live Casino Game Financial Report    
	SELECT 675, 250  UNION ALL -- Live Casino Game Statistics    
	SELECT 762, 139  UNION ALL -- Number Game Win Loss by Bettype    
	SELECT 677, 140  UNION ALL -- Number Game Win Loss by Date    
	SELECT 762, 141  UNION ALL -- Number Game Win Loss by Match    
	SELECT 679, 269  UNION ALL -- Number Game Win Loss By Currency    
	SELECT 680, 165  UNION ALL -- Number Game Monthly Winloss    
	SELECT 681, 291  UNION ALL -- Number Game Financial Report    
	SELECT 682, 162  UNION ALL -- Number of Active Members    
	SELECT 683, 89  UNION ALL -- Bingo Win Loss    
	SELECT 684, 270  UNION ALL -- Bingo Monthly Win Loss    
	SELECT 685, 246  UNION ALL -- Poker Win Loss    
	SELECT 686, 274  UNION ALL -- Virtual Sport Win Loss    
	SELECT 751, 309  UNION ALL -- Bingo OutStanding 
	SELECT 752, 310  UNION ALL -- Bingo Statistic    
	SELECT 689, 278  UNION ALL -- Report Racing Number Active Members    
	SELECT 690, 167  UNION ALL -- Horse Racing Daily (for UK Tote)    
	SELECT 691, 168  UNION ALL -- Horse Racing Daily (for Aust Tote)    
	SELECT 692, 169  UNION ALL -- Greyhound Daily (for UK Tote)    
	SELECT 693, 170  UNION ALL -- Greyhound Daily (for Aust Tote)    
	SELECT 694, 171  UNION ALL -- Harness Daily (for Aust)    
	SELECT 695, 142  UNION ALL -- Horse Racing (for SA Tote)    
	SELECT 696, 143  UNION ALL -- Horse Racing (for OpenTote)    
	SELECT 697, 149  UNION ALL -- Horse Racing Group Daily    
	SELECT 698, 150  UNION ALL -- Horse Racing Group Daily (for Tote)    
	SELECT 699, 186  UNION ALL -- Racing Win Lost By Licensee    
	SELECT 700, 199  UNION ALL -- Horse Racing Daily Report for SA Tote New    
	SELECT 687, 200  UNION ALL -- MA Monitor Tool    
	SELECT 546, 173  UNION ALL -- Number of Bets for Credit Sites    
	SELECT 728, 308  UNION ALL -- Total SMA and Member Active 
	SELECT 867, 328  UNION ALL -- Total Credit Accounts Enabled/Disabled per Product	
	SELECT 547, 272  UNION ALL -- Bet Count    
	SELECT 548, 156  UNION ALL -- Daily Created Customers    
	SELECT 707, 293  UNION ALL -- Duplicate Tickets    
	SELECT 701, 202  UNION ALL -- Betting Graph    
	SELECT 543, 203  UNION ALL -- Check Bet    
	SELECT 542, 205  UNION ALL -- Parlay Won    
	SELECT 702, 204  UNION ALL -- Reporting Services    
	SELECT 703, 206  UNION ALL -- Agency Analysis    
	SELECT 704, 207  UNION ALL -- Punter Analysis    
	SELECT 868, 327  UNION ALL -- SMA Turnover by Product
	SELECT 705, 208  UNION ALL -- Margin Report    
	SELECT 706, 247  UNION ALL -- Daily Turnover    
	SELECT 549, 248  UNION ALL -- Special Match Analysis    
	SELECT 651, 125  UNION ALL -- Report Main    
	SELECT 648, 127  UNION ALL -- Balance Reports    
	SELECT 663, 131  UNION ALL -- Report Win/Loss    
	SELECT 482, 151  UNION ALL -- Licensee Reports    
	SELECT 671, 138  UNION ALL -- Report Gaming    
	SELECT 688, 137  UNION ALL -- Racing Reports    
	SELECT 545, 155  UNION ALL -- Misc Reports    
	SELECT 541, 201	 UNION ALL -- Special Reports    
	SELECT 753, 95	 UNION ALL -- ViewFinanceAccount    
	SELECT 888, 330	 UNION ALL -- Save Bet    
	SELECT 862, 323	 UNION ALL -- Smart Punter    
	SELECT 916, 296 UNION ALL -- Invoice Management System    
	SELECT 917, 296 UNION ALL -- Settlement Report    
	SELECT 918, 296		   -- Create Invoice   

	-- Import group permission    
/*		
	INSERT INTO dbo.GroupFunction (    
		GroupId,     
		FunctionId,     
		SiteId,     
		Policy,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT    
		t.NAPGroupId,    
		t.FunctionId,    
		t.SiteId,    
		MAX(t.Policy),   
		0,   -- CreatedBy    
		GETDATE(),    
		0,   -- ModifiedBy    
		GETDATE()    
	FROM    
		(    
			SELECT DISTINCT     
				gmt.NAPGroupId,    
				f.FunctionId,    
				@AccountingReportSiteId AS SiteId,        
				CASE gp.Policy    
					WHEN 0 THEN 0  -- None    
					WHEN 1 THEN 1  -- Read    
					ELSE CASE          
							WHEN f.CRUD = 0 THEN 1    
							WHEN f.CRUD = 1 THEN 2    
						END      
				END AS Policy    
			FROM     
				DBPOLICY.bodb02.dbo.Acc_GroupPolicy_1 AS gp WITH (NOLOCK)    
				INNER JOIN @FunctionMappingTable AS fmt ON gp.FuncID = fmt.AccountingFunctionId    
				INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
				INNER JOIN @GroupMappingTable AS gmt ON gp.GroupID = gmt.AccountingGroupId
			WHERE     
				gp.FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @FunctionMappingTable )    
				AND NOT EXISTS ( SELECT 1     
						FROM dbo.GroupFunction AS gf WITH (NOLOCK)     
						WHERE gf.GroupId = gmt.NAPGroupId AND gf.FunctionId = f.FunctionId )    
		) AS t   
	GROUP BY
		t.NAPGroupId,    
		t.FunctionId,    
		t.SiteId 

	-- Update group permission 
	
	UPDATE gf
	SET gf.Policy = CASE gp.Policy    
						WHEN 0 THEN 0  -- None    
						WHEN 1 THEN 1  -- Read    
						ELSE CASE          
								WHEN f.CRUD = 0 THEN 1    
								WHEN f.CRUD = 1 THEN 2    
							END     
					END     
	FROM     
		dbo.GroupFunction AS gf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @FunctionMappingTable AS fmt ON gf.FunctionId = fmt.NAPFunctionId    
		INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId    
		INNER JOIN @GroupMappingTable AS gmt ON gf.GroupID = gmt.NAPGroupId
		INNER JOIN DBPOLICY.bodb02.dbo.Acc_GroupPolicy_1 AS gp WITH (NOLOCK)   
			ON     
				gmt.AccountingGroupId = gp.GroupID    
				AND gp.FuncID = fmt.AccountingFunctionId      
	WHERE     
		(gf.Policy = 0 AND gp.Policy <> 0)     
		OR (gf.Policy = 1 AND gp.Policy <> 1)  
		OR (gf.Policy > 1 AND gp.Policy = 0)  
		OR (gf.Policy > 1 AND gp.Policy = 1 AND f.CRUD = 1)

	-- Import users    

	INSERT INTO dbo.Users (    
		UserId,     
		GroupId,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT     
		m.CustID,    
		gmt.NAPGroupId,       
		0,     -- Created by    
		GETDATE(),    
		0,     -- Modified by    
		GETDATE()    
	FROM     
		(    
			SELECT DISTINCT CustID    
			FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
			WHERE     				
				FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @FunctionMappingTable)    
				AND Policy > 0
				AND CustId NOT IN ( SELECT UserId FROM dbo.Users WITH (NOLOCK) )    
				
		) AS m    
		INNER JOIN DBPOLICY.bodb02.dbo.accCustomer_1 AS c WITH (NOLOCK) ON m.CustID = c.custid    
		INNER JOIN @GroupMappingTable AS gmt ON c.GroupID = gmt.AccountingGroupId   

	-- Import user site    

	INSERT INTO UserSite (    
		UserId,    
		SiteId,    
		Level,    
		IsActive,    
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT     
		t.CustID,    
		@AccountingReportSiteId,      
		0,      -- User    
		1,      -- IsActive    
		0,      -- CreatedBy    
		GETDATE(),    
		0,      -- ModifiedBy    
		GETDATE()    
	FROM     
		(    
			SELECT DISTINCT CustID    
			FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
			WHERE     
				FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @FunctionMappingTable)    
				AND Policy > 0
				AND CustId NOT IN ( SELECT UserId     
									FROM dbo.UserSite WITH (NOLOCK)     
									WHERE SiteId = @AccountingReportSiteId )    
		) AS t    

	-- Import user permission    

	INSERT INTO dbo.UserFunction (    
		UserId,     
		FunctionId,     
		SiteId,     
		Policy,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT    
		t.CustID,    
		t.FunctionId,    
		t.SiteId,    
		MAX(t.Policy),   
		0,   -- CreatedBy    
		GETDATE(),    
		0,   -- ModifiedBy    
		GETDATE()    
	FROM    
		(    
			SELECT DISTINCT     
				mp.CustID,    
				f.FunctionId,    
				@AccountingReportSiteId AS SiteId,        
				CASE     
					WHEN us.Level >= 50 THEN CASE      -- Site Admin     
												WHEN f.CRUD = 0 THEN 1    
												WHEN f.CRUD = 1 THEN 2    
												END      
					ELSE CASE mp.Policy    
							WHEN 0 THEN 0  -- None    
							WHEN 1 THEN 1  -- Read    
							ELSE CASE          
									WHEN f.CRUD = 0 THEN 1    
									WHEN f.CRUD = 1 THEN 2    
								END      
					END    
				END AS Policy    
			FROM     
			DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 AS mp WITH (NOLOCK)    
			INNER JOIN @FunctionMappingTable AS fmt ON mp.FuncID = fmt.AccountingFunctionId    
			INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
			INNER JOIN dbo.UserSite AS us WITH (NOLOCK)     
				ON     
				mp.CustID = us.UserId    
				AND us.SiteId = @AccountingReportSiteId    
			WHERE     
			mp.FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @FunctionMappingTable )    
			AND NOT EXISTS ( SELECT 1     
					FROM dbo.UserFunction AS uf WITH (NOLOCK)     
					WHERE uf.UserId = mp.CustID AND uf.FunctionId = f.FunctionId )    
		) AS t   
	GROUP BY
		t.CustID,    
		t.FunctionId,    
		t.SiteId 

	-- Update user permission    

	UPDATE uf
	SET uf.Policy = CASE mp.Policy    
						WHEN 0 THEN 0  -- None    
						WHEN 1 THEN 1  -- Read    
						ELSE CASE          
								WHEN f.CRUD = 0 THEN 1    
								WHEN f.CRUD = 1 THEN 2    
							END     
					END     
	FROM     
		dbo.UserFunction AS uf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @FunctionMappingTable AS fmt ON uf.FunctionId = fmt.NAPFunctionId    
		INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON uf.FunctionId = f.FunctionId    
		INNER JOIN dbo.UserSite AS us WITH (NOLOCK)
			ON     
				uf.UserId = us.UserId    
				AND us.SiteId = @AccountingReportSiteId    
		INNER JOIN DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 AS mp WITH (NOLOCK)   
			ON     
				uf.UserId = mp.CustID    
				AND mp.FuncID = fmt.AccountingFunctionId    
	WHERE     
		us.Level = 0 -- User    
		AND ((uf.Policy = 0 AND mp.Policy <> 0)     
		OR (uf.Policy = 1 AND mp.Policy <> 1)  
		OR (uf.Policy > 1 AND mp.Policy = 0)  
		OR (uf.Policy > 1 AND mp.Policy = 1 AND f.CRUD = 1))     
*/
	-- End Accounting Report

	-- Begin Special Delete

	-- Data preparation    

	DECLARE @SpecialDeleteFunctionMappingTable TABLE (    
		NAPFunctionId			INT,    
		AccountingFunctionId	INT)    

	----  Local test    
	--INSERT INTO @SpecialDeleteFunctionMappingTable (NAPFunctionId, AccountingFunctionId)    
	--SELECT 674, 115  UNION ALL -- Special Delete Sportsbook
	--SELECT 674, 118  UNION ALL -- Special Delete Sportsbook
	--SELECT 674, 212  UNION ALL -- Special Delete Sportsbook
	--SELECT 674, 218  UNION ALL -- Special Delete Sportsbook
	--SELECT 773, 115  UNION ALL -- Void Single Bet
	--SELECT 675, 218  UNION ALL -- Void Parlay Bet    
	--SELECT 802, 115  UNION ALL -- Void Outright Bet 
	--SELECT 679, 212  UNION ALL -- Void Early Kick-off   
	--SELECT 676, 118  UNION ALL -- Recover Sportsbook Bet   
	--SELECT 803, 118  UNION ALL -- Recover Number Game Bet
	--SELECT 804, 118  UNION ALL -- Recover Live Casino Bet
	--SELECT 800, 118  UNION ALL -- Live Casino Special Delete
	--SELECT 801, 118  UNION ALL -- Number Game Special Delete
	--SELECT 680, 251  UNION ALL -- Void Live Casino Bet
	--SELECT 677, 114  UNION ALL -- Void Number Game Bet  
	--SELECT 678, 92  UNION ALL -- Upload Batch Msg
	----SELECT 681, 127  UNION ALL -- Special Delete VirtualSports    
	--SELECT 682, 225     -- Tickets Listing    

	-- Production    

	INSERT INTO @SpecialDeleteFunctionMappingTable (NAPFunctionId, AccountingFunctionId)    
	SELECT 725, 115	UNION ALL	-- Sportsbook Special Delete 
	SELECT 725, 218	UNION ALL	-- Sportsbook Special Delete 
	SELECT 725, 118	UNION ALL	-- Sportsbook Special Delete 
	SELECT 725, 212	UNION ALL	-- Sportsbook Special Delete 
	SELECT 740, 118	UNION ALL	-- Recover Sportsbook Bet 
	SELECT 743, 212	UNION ALL	-- Void Early KickOff Bet 
	SELECT 739, 115	UNION ALL	-- Void Outright Bet 
	SELECT 738, 218	UNION ALL	-- Void Parlay Bet 
	SELECT 757, 115	UNION ALL	-- Void Single Bet 
	SELECT 741, 114	UNION ALL	-- Number Game Special Delete 
	SELECT 741, 118	UNION ALL	-- Number Game Special Delete 
	SELECT 761, 118	UNION ALL	-- Recover Number Game Bet 
	SELECT 760, 114	UNION ALL	-- Void Number Game Bet 
	SELECT 744, 251	UNION ALL	-- Live Casino Special Delete 
	SELECT 744, 118	UNION ALL	-- Live Casino Special Delete 
	SELECT 759, 118	UNION ALL	-- Recover Live Casino Bet  
	SELECT 758, 251	UNION ALL	-- Void Live Casino Bet  
	SELECT 726, 225	UNION ALL	-- Ticket Listing
	SELECT 742, 92	UNION ALL	-- Update Batch Message
	SELECT 745, 273	UNION ALL  	-- Virtual Sports
	SELECT 897, 333	UNION ALL 	-- Void By Bet ID
	SELECT 897, 334	UNION ALL	-- Void By Bet ID
	SELECT 897, 335 UNION ALL 	-- Void By Bet ID
	SELECT 899, 334 UNION ALL 	-- Void Unsettled Tickets
	SELECT 898, 335			 	-- Void settled tickets

	-- Import group permission    
/*		
	INSERT INTO dbo.GroupFunction (    
		GroupId,     
		FunctionId,     
		SiteId,     
		Policy,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT    
		t.NAPGroupId,    
		t.FunctionId,    
		t.SiteId,    
		MAX(t.Policy),   
		0,   -- CreatedBy    
		GETDATE(),    
		0,   -- ModifiedBy    
		GETDATE()    
	FROM    
		(    
			SELECT DISTINCT     
				gmt.NAPGroupId,    
				f.FunctionId,    
				@SpecialDeleteSiteId AS SiteId,        
				CASE gp.Policy    
					WHEN 0 THEN 0  -- None    
					WHEN 1 THEN 1  -- Read    
					ELSE CASE          
							WHEN f.CRUD = 0 THEN 1    
							WHEN f.CRUD = 1 THEN 2    
						END      
				END AS Policy    
			FROM     
				DBPOLICY.bodb02.dbo.Acc_GroupPolicy_1 AS gp WITH (NOLOCK)    
				INNER JOIN @SpecialDeleteFunctionMappingTable AS fmt ON gp.FuncID = fmt.AccountingFunctionId    
				INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
				INNER JOIN @GroupMappingTable AS gmt ON gp.GroupID = gmt.AccountingGroupId
			WHERE     
				--gp.FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @SpecialDeleteFunctionMappingTable )    
				NOT EXISTS ( SELECT 1     
						FROM dbo.GroupFunction AS gf WITH (NOLOCK)     
						WHERE gf.GroupId = gmt.NAPGroupId AND gf.FunctionId = f.FunctionId )    
		) AS t   
	GROUP BY
		t.NAPGroupId,    
		t.FunctionId,    
		t.SiteId 

	-- Update group permission 
	
	UPDATE gf
	SET gf.Policy = CASE gp.Policy    
						WHEN 0 THEN 0  -- None    
						WHEN 1 THEN 1  -- Read    
						ELSE CASE          
								WHEN f.CRUD = 0 THEN 1    
								WHEN f.CRUD = 1 THEN 2    
							END     
					END     
	FROM     
		dbo.GroupFunction AS gf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @SpecialDeleteFunctionMappingTable AS fmt ON gf.FunctionId = fmt.NAPFunctionId    
		INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId    
		INNER JOIN @GroupMappingTable AS gmt ON gf.GroupID = gmt.NAPGroupId
		INNER JOIN DBPOLICY.bodb02.dbo.Acc_GroupPolicy_1 AS gp WITH (NOLOCK)   
			ON     
				gmt.AccountingGroupId = gp.GroupID    
				AND gp.FuncID = fmt.AccountingFunctionId      
	WHERE     
		(gf.Policy = 0 AND gp.Policy <> 0)     
		OR (gf.Policy = 1 AND gp.Policy <> 1)  
		OR (gf.Policy > 1 AND gp.Policy = 0)  
		OR (gf.Policy > 1 AND gp.Policy = 1 AND f.CRUD = 1)
	     
	-- Import users    
    
	INSERT INTO dbo.Users (    
		UserId,     
		GroupId,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT     
		m.CustID,    
		gmt.NAPGroupId,       
		0,     -- Created by    
		GETDATE(),    
		0,     -- Modified by    
		GETDATE()    
	FROM     
		(    
			SELECT DISTINCT CustID    
			FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
			WHERE     
				FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @SpecialDeleteFunctionMappingTable)    
				AND Policy > 0
				AND CustId NOT IN ( SELECT UserId FROM dbo.Users WITH (NOLOCK) )    
		) AS m    
		INNER JOIN DBPOLICY.bodb02.dbo.accCustomer_1 AS c WITH (NOLOCK) ON m.CustID = c.custid    
		INNER JOIN @GroupMappingTable AS gmt ON c.GroupID = gmt.AccountingGroupId    

	-- Import user site    

	INSERT INTO UserSite (    
		UserId,    
		SiteId,    
		Level,    
		IsActive,    
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT     
		t.CustID,    
		@SpecialDeleteSiteId,      
		0,      -- User    
		1,      -- IsActive    
		0,      -- CreatedBy    
		GETDATE(),    
		0,      -- ModifiedBy    
		GETDATE()    
	FROM     
		(    
			SELECT DISTINCT CustID    
			FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
			WHERE     
				FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @SpecialDeleteFunctionMappingTable)    
				AND Policy > 0
				AND CustId NOT IN ( SELECT UserId     
									FROM dbo.UserSite WITH (NOLOCK)     
									WHERE SiteId = @SpecialDeleteSiteId )    
		) AS t    

	-- Import user permission    

	INSERT INTO dbo.UserFunction (    
		UserId,     
		FunctionId,     
		SiteId,     
		Policy,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT    
		t.CustID,    
		t.FunctionId,    
		t.SiteId,    
		MAX(t.Policy),    
		0,   -- CreatedBy    
		GETDATE(),    
		0,   -- ModifiedBy    
		GETDATE()    
	FROM    
		(    
			SELECT DISTINCT     
				mp.CustID,    
				f.FunctionId,    
				@SpecialDeleteSiteId AS SiteId,        
				CASE     
					WHEN us.Level >= 50 THEN CASE      -- Site Admin     
						WHEN f.CRUD = 0 THEN 1    
						WHEN f.CRUD = 1 THEN 2    
						END      
					ELSE CASE mp.Policy    
							WHEN 0 THEN 0  -- None    
							WHEN 1 THEN 1  -- Read    
							ELSE CASE          
									WHEN f.CRUD = 0 THEN 1    
									WHEN f.CRUD = 1 THEN 2    
								END      
					END    
				END AS Policy    
			FROM     
				DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 AS mp WITH (NOLOCK)    
				INNER JOIN @SpecialDeleteFunctionMappingTable AS fmt ON mp.FuncID = fmt.AccountingFunctionId    
				INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
				INNER JOIN dbo.UserSite AS us WITH (NOLOCK)     
					ON     
					mp.CustID = us.UserId    
					AND us.SiteId = @SpecialDeleteSiteId    
			WHERE     
				mp.FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @SpecialDeleteFunctionMappingTable )    
				AND NOT EXISTS (	SELECT 1 FROM dbo.UserFunction AS uf WITH (NOLOCK)   
									WHERE uf.UserId = mp.CustID AND uf.FunctionId = f.FunctionId )    
		) AS t     
	GROUP BY
		t.CustID,    
		t.FunctionId,    
		t.SiteId 

	-- Update user permission    

	UPDATE uf    
	SET uf.Policy = CASE temp.MaxPolicy    
						WHEN 0 THEN 0  -- None    
						WHEN 1 THEN 1  -- Read    
						ELSE CASE          
								WHEN temp.CRUD = 0 THEN 1    
								WHEN temp.CRUD = 1 THEN 2    
							END     
					END     
	FROM     		
		dbo.UserFunction AS uf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN
			(
				SELECT    
					uf.UserId,
					uf.FunctionId,
					us.Level,					
					f.CRUD,
					MAX(mp.Policy) AS MaxPolicy
				FROM 
					dbo.UserFunction AS uf WITH (NOLOCK)
					INNER JOIN @SpecialDeleteFunctionMappingTable AS fmt ON uf.FunctionId = fmt.NAPFunctionId    
					INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
					INNER JOIN dbo.UserSite AS us     
						ON     
							uf.UserId = us.UserId    
							AND us.SiteId = @SpecialDeleteSiteId    
					INNER JOIN DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 AS mp WITH (NOLOCK)  
						ON     
							uf.UserId = mp.CustID    
							AND mp.FuncID = fmt.AccountingFunctionId    
				GROUP BY
					uf.UserId,
					uf.FunctionId,
					us.Level,					
					f.CRUD
			) AS temp
		ON uf.FunctionId = temp.FunctionId AND uf.UserId = temp.UserId
	WHERE     
		temp.Level = 0 -- User    
		AND ((uf.Policy = 0 AND temp.MaxPolicy <> 0)     
		OR (uf.Policy = 1 AND temp.MaxPolicy <> 1)  
		OR (uf.Policy > 1 AND temp.MaxPolicy = 0)  
		OR (uf.Policy > 1 AND temp.MaxPolicy = 1 AND temp.CRUD = 1))     
*/
	-- End Special Delete

	-- Begin Customer Management

	-- Data preparation    

	DECLARE @CustomerManagementFunctionMappingTable TABLE (    
		NAPFunctionId			INT,    
		AccountingFunctionId	INT)    

	----  Local test    
	--INSERT INTO @CustomerManagementFunctionMappingTable (NAPFunctionId, AccountingFunctionId)    
	--SELECT 894, 313	UNION ALL	-- Configure Customer 
	--SELECT 894, 314	UNION ALL	-- Configure Customer 
	--SELECT 894, 349	UNION ALL	-- Configure Customer 
	--SELECT 893, 313	UNION ALL	-- Close/Open Members 
	--SELECT 896, 314 UNION ALL	-- Configure Customer Access 
	--SELECT 940, 349 UNION ALL	-- Manage Robot
	--SELECT 909, 298	UNION ALL	-- Control Turnover
	--SELECT 910, 344	UNION ALL	-- Control TO By Event
	--SELECT 911, 345	UNION ALL	-- Control TO By SMA
	--SELECT 916, 346	UNION ALL	-- Control TO By SMA & Event
	--SELECT 921, 347	UNION ALL	-- Turnover Monitor
	--SELECT 912, 348  	UNION ALL	-- Turnover Usage
	--SELECT 857, 320	UNION ALL	-- Turnover Monitor
	--SELECT 859, 321  	UNION ALL	-- Turnover Usage
	--SELECT 962, 336 UNION ALL 	-- TurnoverControl
	--SELECT 963, 337 UNION ALL 	-- Global Setting
	--SELECT 912, 338 UNION ALL 	-- Turnover Monitor
	--SELECT 964, 339 UNION ALL 	-- Notification Setting
	--SELECT 965, 340  			-- Turnover Control Notification

	-- Production    

	INSERT INTO @CustomerManagementFunctionMappingTable (NAPFunctionId, AccountingFunctionId)    
	SELECT 831, 313	UNION ALL	-- Configure Customer 
	SELECT 831, 314	UNION ALL	-- Configure Customer 
	SELECT 831, 326	UNION ALL	-- Configure Customer 
	SELECT 831, 323	UNION ALL	-- Configure Customer 
	SELECT 850, 313	UNION ALL	-- Close/Open Members 
	SELECT 830, 314	UNION ALL	-- Configure Customer Access  
	SELECT 864, 326 UNION ALL	-- Manage Robot
	SELECT 887, 323 UNION ALL	-- Manage Smart Punter
	SELECT 853, 298	UNION ALL	-- Control Turnover
	SELECT 854, 317	UNION ALL	-- Control TO By Event
	SELECT 855, 318	UNION ALL	-- Control TO By SMA
	SELECT 856, 319	UNION ALL	-- Control TO By SMA & Event
	SELECT 857, 320	UNION ALL	-- Turnover Monitor
	SELECT 859, 321 UNION ALL	-- Turnover Usage
	SELECT 860, 324	UNION ALL	-- Loss Control
	SELECT 861, 325 UNION ALL  	-- Loss Monitor
	SELECT 921, 338 UNION ALL 	-- TurnoverControl
	SELECT 922, 340 UNION ALL 	-- Global Setting
	SELECT 857, 341 UNION ALL 	-- Turnover Monitor
	SELECT 923, 339 UNION ALL 	-- Notification Setting
	SELECT 924, 342  			-- Turnover Control Notification


	-- Import group permission    
		
	INSERT INTO dbo.GroupFunction (    
		GroupId,     
		FunctionId,     
		SiteId,     
		Policy,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT    
		t.NAPGroupId,    
		t.FunctionId,    
		t.SiteId,    
		MAX(t.Policy),   
		0,   -- CreatedBy    
		GETDATE(),    
		0,   -- ModifiedBy    
		GETDATE()    
	FROM    
		(    
			SELECT DISTINCT     
				gmt.NAPGroupId,    
				f.FunctionId,    
				@CustomerManagementSiteId AS SiteId,        
				CASE gp.Policy    
					WHEN 0 THEN 0  -- None    
					WHEN 1 THEN 1  -- Read    
					ELSE CASE          
							WHEN f.CRUD = 0 THEN 1    
							WHEN f.CRUD = 1 THEN 2    
						END      
				END AS Policy    
			FROM     
				DBPOLICY.bodb02.dbo.Acc_GroupPolicy_1 AS gp WITH (NOLOCK)    
				INNER JOIN @CustomerManagementFunctionMappingTable AS fmt ON gp.FuncID = fmt.AccountingFunctionId    
				INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
				INNER JOIN @GroupMappingTable AS gmt ON gp.GroupID = gmt.AccountingGroupId
			WHERE     
				--gp.FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @CustomerManagementFunctionMappingTable )    
				NOT EXISTS ( SELECT 1     
						FROM dbo.GroupFunction AS gf WITH (NOLOCK)     
						WHERE gf.GroupId = gmt.NAPGroupId AND gf.FunctionId = f.FunctionId )    
		) AS t   
	GROUP BY
		t.NAPGroupId,    
		t.FunctionId,    
		t.SiteId 

	-- Update group permission 
	
	UPDATE gf
	SET gf.Policy = CASE gp.Policy    
						WHEN 0 THEN 0  -- None    
						WHEN 1 THEN 1  -- Read    
						ELSE CASE          
								WHEN f.CRUD = 0 THEN 1    
								WHEN f.CRUD = 1 THEN 2    
							END     
					END     
	FROM     
		dbo.GroupFunction AS gf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @CustomerManagementFunctionMappingTable AS fmt ON gf.FunctionId = fmt.NAPFunctionId    
		INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId    
		INNER JOIN @GroupMappingTable AS gmt ON gf.GroupID = gmt.NAPGroupId
		INNER JOIN DBPOLICY.bodb02.dbo.Acc_GroupPolicy_1 AS gp WITH (NOLOCK)   
			ON     
				gmt.AccountingGroupId = gp.GroupID    
				AND gp.FuncID = fmt.AccountingFunctionId      
	WHERE     
		(gf.Policy = 0 AND gp.Policy <> 0)     
		OR (gf.Policy = 1 AND gp.Policy <> 1)  
		OR (gf.Policy > 1 AND gp.Policy = 0)  
		OR (gf.Policy > 1 AND gp.Policy = 1 AND f.CRUD = 1)
	     
	-- Import users    
    
	INSERT INTO dbo.Users (    
		UserId,     
		GroupId,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT     
		m.CustID,    
		gmt.NAPGroupId,       
		0,     -- Created by    
		GETDATE(),    
		0,     -- Modified by    
		GETDATE()    
	FROM     
		(    
			SELECT DISTINCT CustID    
			FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
			WHERE     
				FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @CustomerManagementFunctionMappingTable)    
				AND Policy > 0
				AND CustId NOT IN ( SELECT UserId FROM dbo.Users WITH (NOLOCK) )    
		) AS m    
		INNER JOIN DBPOLICY.bodb02.dbo.accCustomer_1 AS c WITH (NOLOCK) ON m.CustID = c.custid    
		INNER JOIN @GroupMappingTable AS gmt ON c.GroupID = gmt.AccountingGroupId    

	-- Import user site    

	INSERT INTO UserSite (    
		UserId,    
		SiteId,    
		Level,    
		IsActive,    
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT     
		t.CustID,    
		@CustomerManagementSiteId,      
		0,      -- User    
		1,      -- IsActive    
		0,      -- CreatedBy    
		GETDATE(),    
		0,      -- ModifiedBy    
		GETDATE()    
	FROM     
		(    
			SELECT DISTINCT CustID    
			FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
			WHERE     
				FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @CustomerManagementFunctionMappingTable)    
				AND Policy > 0
				AND CustId NOT IN ( SELECT UserId     
									FROM dbo.UserSite WITH (NOLOCK)     
									WHERE SiteId = @CustomerManagementSiteId )    
		) AS t    

	-- Import user permission    

	INSERT INTO dbo.UserFunction (    
		UserId,     
		FunctionId,     
		SiteId,     
		Policy,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT    
		t.CustID,    
		t.FunctionId,    
		t.SiteId,    
		MAX(t.Policy),    
		0,   -- CreatedBy    
		GETDATE(),    
		0,   -- ModifiedBy    
		GETDATE()    
	FROM    
		(    
			SELECT DISTINCT     
				mp.CustID,    
				f.FunctionId,    
				@CustomerManagementSiteId AS SiteId,        
				CASE     
					WHEN us.Level >= 50 THEN CASE      -- Site Admin     
						WHEN f.CRUD = 0 THEN 1    
						WHEN f.CRUD = 1 THEN 2    
						END      
					ELSE CASE mp.Policy    
							WHEN 0 THEN 0  -- None    
							WHEN 1 THEN 1  -- Read    
							ELSE CASE          
									WHEN f.CRUD = 0 THEN 1    
									WHEN f.CRUD = 1 THEN 2    
								END      
					END    
				END AS Policy    
			FROM     
				DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 AS mp WITH (NOLOCK)    
				INNER JOIN @CustomerManagementFunctionMappingTable AS fmt ON mp.FuncID = fmt.AccountingFunctionId    
				INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
				INNER JOIN dbo.UserSite AS us WITH (NOLOCK)     
					ON     
					mp.CustID = us.UserId    
					AND us.SiteId = @CustomerManagementSiteId    
			WHERE     
				mp.FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @CustomerManagementFunctionMappingTable )    
				AND NOT EXISTS (	SELECT 1 FROM dbo.UserFunction AS uf WITH (NOLOCK)   
									WHERE uf.UserId = mp.CustID AND uf.FunctionId = f.FunctionId )    
		) AS t     
	GROUP BY
		t.CustID,    
		t.FunctionId,    
		t.SiteId 

	-- Update user permission    

	UPDATE uf    
	SET uf.Policy = CASE temp.MaxPolicy    
						WHEN 0 THEN 0  -- None    
						WHEN 1 THEN 1  -- Read    
						ELSE CASE          
								WHEN temp.CRUD = 0 THEN 1    
								WHEN temp.CRUD = 1 THEN 2    
							END     
					END     
	FROM     		
		dbo.UserFunction AS uf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN
			(
				SELECT    
					uf.UserId,
					uf.FunctionId,
					us.Level,					
					f.CRUD,
					MAX(mp.Policy) AS MaxPolicy
				FROM 
					dbo.UserFunction AS uf WITH (NOLOCK)
					INNER JOIN @CustomerManagementFunctionMappingTable AS fmt ON uf.FunctionId = fmt.NAPFunctionId    
					INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
					INNER JOIN dbo.UserSite AS us     
						ON     
							uf.UserId = us.UserId    
							AND us.SiteId = @CustomerManagementSiteId    
					INNER JOIN DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 AS mp WITH (NOLOCK)  
						ON     
							uf.UserId = mp.CustID    
							AND mp.FuncID = fmt.AccountingFunctionId    
				GROUP BY
					uf.UserId,
					uf.FunctionId,
					us.Level,					
					f.CRUD
			) AS temp
		ON uf.FunctionId = temp.FunctionId AND uf.UserId = temp.UserId
	WHERE     
		temp.Level = 0 -- User    
		AND ((uf.Policy = 0 AND temp.MaxPolicy <> 0)     
		OR (uf.Policy = 1 AND temp.MaxPolicy <> 1)  
		OR (uf.Policy > 1 AND temp.MaxPolicy = 0)  
		OR (uf.Policy > 1 AND temp.MaxPolicy = 1 AND temp.CRUD = 1))     

	-- End CustomerManagement

	-- Begin Settlement

	-- Data preparation    

	DECLARE @SettlementFunctionMappingTable TABLE (    
		NAPFunctionId			INT,    
		AccountingFunctionId	INT)    

	----  Local test    
	--INSERT INTO @SettlementFunctionMappingTable (NAPFunctionId, AccountingFunctionId)    
	--SELECT 603, 32	UNION ALL	-- Sportsbook Mark Pending Match
	--SELECT 604, 252	UNION ALL	-- Sportsbook Mark Undecide Match
	--SELECT 606, 32	UNION ALL	-- Sportsbook Settlement
	--SELECT 606, 33	UNION ALL	-- Sportsbook Settlement 
	--SELECT 607, 32	UNION ALL	-- Sportsbook Calculate
	--SELECT 608, 32	UNION ALL	-- Sportsbook Refund
	--SELECT 609, 33	UNION ALL	-- Sportsbook Uncalculate
	--SELECT 610, 32	UNION ALL	-- Sportsbook Calculate MixParlay
	--SELECT 602, 32	UNION ALL	-- Prepare Sportsbook Settlement
	--SELECT 602, 252	UNION ALL	-- Prepare Sportsbook Settlement 	
	--SELECT 614, 249	UNION ALL	-- Live Casino Settlement 
	--SELECT 617, 249	UNION ALL	-- Live Casino View Result
	--SELECT 615, 249	UNION ALL	-- Live Casino Recalculate
	--SELECT 616, 249	UNION ALL	-- Live Casino Refund
	--SELECT 613, 249	UNION ALL	-- Prepare Live Casino Settlement
	--SELECT 612, 32	UNION ALL	-- NumberGame Recalculate 
	--SELECT 620, 32	UNION ALL	-- NumberGame View Result 
	--SELECT 611, 32	UNION ALL	-- NumberGame Settlement 
	--SELECT 618, 59	UNION ALL	-- View Log Settlement 
	--SELECT 619, 32  			-- View Result Settlement 

	-- Production    

	INSERT INTO @SettlementFunctionMappingTable (NAPFunctionId, AccountingFunctionId)    
	SELECT 796, 32	UNION ALL	-- Sportsbook Mark Pending Match
	SELECT 797, 252	UNION ALL	-- Sportsbook Mark Undecide Match
	SELECT 798, 32	UNION ALL	-- Sportsbook Settlement
	SELECT 798, 33	UNION ALL	-- Sportsbook Settlement 
	SELECT 799, 32	UNION ALL	-- Sportsbook Calculate
	SELECT 800, 32	UNION ALL	-- Sportsbook Refund
	SELECT 801, 33	UNION ALL	-- Sportsbook Uncalculate
	SELECT 802, 32	UNION ALL	-- Sportsbook Calculate MixParlay
	SELECT 795, 32	UNION ALL	-- Prepare Sportsbook Settlement
	SELECT 795, 252	UNION ALL	-- Prepare Sportsbook Settlement 	
	SELECT 846, 249	UNION ALL	-- Live Casino Settlement 
	SELECT 847, 249	UNION ALL	-- Live Casino View Result
	SELECT 848, 249	UNION ALL	-- Live Casino Recalculate
	SELECT 849, 249	UNION ALL	-- Live Casino Refund
	SELECT 845, 249	UNION ALL	-- Prepare Live Casino Settlement
	SELECT 806, 32	UNION ALL	-- NumberGame Recalculate 
	SELECT 807, 32	UNION ALL	-- NumberGame View Result 
	SELECT 805, 32	UNION ALL	-- NumberGame Settlement 
	SELECT 803, 59	UNION ALL	-- View Log Settlement 
	SELECT 804, 32  				-- View Result Settlement 

	-- Import group permission    
/*		
	INSERT INTO dbo.GroupFunction (    
		GroupId,     
		FunctionId,     
		SiteId,     
		Policy,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT    
		t.NAPGroupId,    
		t.FunctionId,    
		t.SiteId,    
		MAX(t.Policy),   
		0,   -- CreatedBy    
		GETDATE(),    
		0,   -- ModifiedBy    
		GETDATE()    
	FROM    
		(    
			SELECT DISTINCT     
				gmt.NAPGroupId,    
				f.FunctionId,    
				@SettlementSiteId AS SiteId,        
				CASE gp.Policy    
					WHEN 0 THEN 0  -- None    
					WHEN 1 THEN 1  -- Read    
					ELSE CASE          
							WHEN f.CRUD = 0 THEN 1    
							WHEN f.CRUD = 1 THEN 2    
						END      
				END AS Policy    
			FROM     
				DBPOLICY.bodb02.dbo.Acc_GroupPolicy_1 AS gp WITH (NOLOCK)    
				INNER JOIN @SettlementFunctionMappingTable AS fmt ON gp.FuncID = fmt.AccountingFunctionId    
				INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
				INNER JOIN @GroupMappingTable AS gmt ON gp.GroupID = gmt.AccountingGroupId
			WHERE     
				--gp.FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @SettlementFunctionMappingTable )    
				NOT EXISTS ( SELECT 1     
						FROM dbo.GroupFunction AS gf WITH (NOLOCK)     
						WHERE gf.GroupId = gmt.NAPGroupId AND gf.FunctionId = f.FunctionId )    
		) AS t   
	GROUP BY
		t.NAPGroupId,    
		t.FunctionId,    
		t.SiteId 

	-- Update group permission 
	
	UPDATE gf
	SET gf.Policy = CASE gp.Policy    
						WHEN 0 THEN 0  -- None    
						WHEN 1 THEN 1  -- Read    
						ELSE CASE          
								WHEN f.CRUD = 0 THEN 1    
								WHEN f.CRUD = 1 THEN 2    
							END     
					END     
	FROM     
		dbo.GroupFunction AS gf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @SettlementFunctionMappingTable AS fmt ON gf.FunctionId = fmt.NAPFunctionId    
		INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId    
		INNER JOIN @GroupMappingTable AS gmt ON gf.GroupID = gmt.NAPGroupId
		INNER JOIN DBPOLICY.bodb02.dbo.Acc_GroupPolicy_1 AS gp WITH (NOLOCK)   
			ON     
				gmt.AccountingGroupId = gp.GroupID    
				AND gp.FuncID = fmt.AccountingFunctionId      
	WHERE     
		(gf.Policy = 0 AND gp.Policy <> 0)     
		OR (gf.Policy = 1 AND gp.Policy <> 1)  
		OR (gf.Policy > 1 AND gp.Policy = 0)  
		OR (gf.Policy > 1 AND gp.Policy = 1 AND f.CRUD = 1)
	     
	-- Import users    
    
	INSERT INTO dbo.Users (    
		UserId,     
		GroupId,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT     
		m.CustID,    
		gmt.NAPGroupId,       
		0,     -- Created by    
		GETDATE(),    
		0,     -- Modified by    
		GETDATE()    
	FROM     
		(    
			SELECT DISTINCT CustID    
			FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
			WHERE     
				FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @SettlementFunctionMappingTable)    
				AND Policy > 0
				AND CustId NOT IN ( SELECT UserId FROM dbo.Users WITH (NOLOCK) )    
		) AS m    
		INNER JOIN DBPOLICY.bodb02.dbo.accCustomer_1 AS c WITH (NOLOCK) ON m.CustID = c.custid    
		INNER JOIN @GroupMappingTable AS gmt ON c.GroupID = gmt.AccountingGroupId    

	-- Import user site    

	INSERT INTO UserSite (    
		UserId,    
		SiteId,    
		Level,    
		IsActive,    
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT     
		t.CustID,    
		@SettlementSiteId,      
		0,      -- User    
		1,      -- IsActive    
		0,      -- CreatedBy    
		GETDATE(),    
		0,      -- ModifiedBy    
		GETDATE()    
	FROM     
		(    
			SELECT DISTINCT CustID    
			FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
			WHERE     
				FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @SettlementFunctionMappingTable)    
				AND Policy > 0
				AND CustId NOT IN ( SELECT UserId     
									FROM dbo.UserSite WITH (NOLOCK)     
									WHERE SiteId = @SettlementSiteId )    
		) AS t    

	UPDATE UserSite WITH (ROWLOCK, UPDLOCK)
	SET IsActive = 1
	WHERE 
		SiteId = @SettlementSiteId
		AND UserId IN (	SELECT DISTINCT CustID    
						FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
						WHERE     
							FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @SettlementFunctionMappingTable)    
							AND Policy > 0
							AND CustId NOT IN ( SELECT UserId     
												FROM dbo.UserSite WITH (NOLOCK)     
												WHERE SiteId = @SettlementSiteId AND IsActive = 1) )

	-- Import user permission    

	INSERT INTO dbo.UserFunction (    
		UserId,     
		FunctionId,     
		SiteId,     
		Policy,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT    
		t.CustID,    
		t.FunctionId,    
		t.SiteId,    
		MAX(t.Policy),    
		0,   -- CreatedBy    
		GETDATE(),    
		0,   -- ModifiedBy    
		GETDATE()    
	FROM    
		(    
			SELECT DISTINCT     
				mp.CustID,    
				f.FunctionId,    
				@SettlementSiteId AS SiteId,        
				CASE     
					WHEN us.Level >= 50 THEN CASE      -- Site Admin     
						WHEN f.CRUD = 0 THEN 1    
						WHEN f.CRUD = 1 THEN 2    
						END      
					ELSE CASE mp.Policy    
							WHEN 0 THEN 0  -- None    
							WHEN 1 THEN 1  -- Read    
							ELSE CASE          
									WHEN f.CRUD = 0 THEN 1    
									WHEN f.CRUD = 1 THEN 2    
								END      
					END    
				END AS Policy    
			FROM     
				DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 AS mp WITH (NOLOCK)    
				INNER JOIN @SettlementFunctionMappingTable AS fmt ON mp.FuncID = fmt.AccountingFunctionId    
				INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
				INNER JOIN dbo.UserSite AS us WITH (NOLOCK)     
					ON     
					mp.CustID = us.UserId    
					AND us.SiteId = @SettlementSiteId    
			WHERE     
				mp.FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @SettlementFunctionMappingTable )    
				AND NOT EXISTS (	SELECT 1 FROM dbo.UserFunction AS uf WITH (NOLOCK)   
									WHERE uf.UserId = mp.CustID AND uf.FunctionId = f.FunctionId )    
		) AS t     
	GROUP BY
		t.CustID,    
		t.FunctionId,    
		t.SiteId 

	-- Update user permission    

	UPDATE uf    
	SET uf.Policy = CASE temp.MaxPolicy    
						WHEN 0 THEN 0  -- None    
						WHEN 1 THEN 1  -- Read    
						ELSE CASE          
								WHEN temp.CRUD = 0 THEN 1    
								WHEN temp.CRUD = 1 THEN 2    
							END     
					END     
	FROM     		
		dbo.UserFunction AS uf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN
			(
				SELECT    
					uf.UserId,
					uf.FunctionId,
					us.Level,					
					f.CRUD,
					MAX(mp.Policy) AS MaxPolicy
				FROM 
					dbo.UserFunction AS uf WITH (NOLOCK)
					INNER JOIN @SettlementFunctionMappingTable AS fmt ON uf.FunctionId = fmt.NAPFunctionId    
					INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
					INNER JOIN dbo.UserSite AS us     
						ON     
							uf.UserId = us.UserId    
							AND us.SiteId = @SettlementSiteId    
					INNER JOIN DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 AS mp WITH (NOLOCK)  
						ON     
							uf.UserId = mp.CustID    
							AND mp.FuncID = fmt.AccountingFunctionId    
				GROUP BY
					uf.UserId,
					uf.FunctionId,
					us.Level,					
					f.CRUD
			) AS temp
		ON uf.FunctionId = temp.FunctionId AND uf.UserId = temp.UserId
	WHERE     
		temp.Level = 0 -- User    
		AND ((uf.Policy = 0 AND temp.MaxPolicy <> 0)     
		OR (uf.Policy = 1 AND temp.MaxPolicy <> 1)  
		OR (uf.Policy > 1 AND temp.MaxPolicy = 0)  
		OR (uf.Policy > 1 AND temp.MaxPolicy = 1 AND temp.CRUD = 1))     

*/
	-- End Settlement

	-- Begin CRM

	-- Data preparation    

	DECLARE @CRMFunctionMappingTable TABLE (    
		NAPFunctionId			INT,    
		AccountingFunctionId	INT)    

	--  Local test    
	--INSERT INTO @CRMFunctionMappingTable (NAPFunctionId, AccountingFunctionId)    
	--SELECT 850, 253	UNION ALL	-- FBSubjectTemplateManagement
	--SELECT 851, 109	UNION ALL	-- SettingManagement 
	--SELECT 852, 110	UNION ALL	-- SettingRelationshipManagement
	--SELECT 846, 108	UNION ALL	-- AdminTool 
	--SELECT 853, 124	UNION ALL	-- Customer/Guest
	--SELECT 847, 123	UNION ALL	-- CRMCustomer 
	--SELECT 848, 122	UNION ALL	-- CRMReport 
	--SELECT 855, 119	UNION ALL	-- CreateFeedback 
	--SELECT 856, 259	UNION ALL	-- DeleteFeedback 
	--SELECT 857, 120	UNION ALL	-- EditFeedback
	--SELECT 870, 121	UNION ALL	-- ReviewFeedback 
	--SELECT 849, 111  			-- Feedback  

	-- Production    

	INSERT INTO @CRMFunctionMappingTable (NAPFunctionId, AccountingFunctionId)    
	SELECT 836, 253	UNION ALL	-- FBSubjectTemplateManagement
	SELECT 837, 109	UNION ALL	-- SettingManagement 
	SELECT 838, 110	UNION ALL	-- SettingRelationshipManagement
	SELECT 835, 108	UNION ALL	-- AdminTool 
	SELECT 840, 124	UNION ALL	-- Customer/Guest
	SELECT 839, 123	UNION ALL	-- CRMCustomer 
	SELECT 818, 122	UNION ALL	-- CRMReport 
	SELECT 820, 119	UNION ALL	-- CreateFeedback 
	SELECT 832, 259	UNION ALL	-- DeleteFeedback 
	SELECT 833, 120	UNION ALL	-- EditFeedback
	SELECT 834, 121	UNION ALL	-- ReviewFeedback 
	SELECT 819, 111  			-- Feedback

	-- Import group permission    
	/*
	INSERT INTO dbo.GroupFunction (    
		GroupId,     
		FunctionId,     
		SiteId,     
		Policy,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT    
		t.NAPGroupId,    
		t.FunctionId,    
		t.SiteId,    
		MAX(t.Policy),   
		0,   -- CreatedBy    
		GETDATE(),    
		0,   -- ModifiedBy    
		GETDATE()    
	FROM    
		(    
			SELECT DISTINCT     
				gmt.NAPGroupId,    
				f.FunctionId,    
				@CRMSiteId AS SiteId,        
				CASE gp.Policy    
					WHEN 0 THEN 0  -- None    
					WHEN 1 THEN 1  -- Read    
					ELSE CASE          
							WHEN f.CRUD = 0 THEN 1    
							WHEN f.CRUD = 1 THEN 2    
						END      
				END AS Policy    
			FROM     
				DBPOLICY.bodb02.dbo.Acc_GroupPolicy_1 AS gp WITH (NOLOCK)    
				INNER JOIN @CRMFunctionMappingTable AS fmt ON gp.FuncID = fmt.AccountingFunctionId    
				INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
				INNER JOIN @GroupMappingTable AS gmt ON gp.GroupID = gmt.AccountingGroupId
			WHERE     
				gp.FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @CRMFunctionMappingTable )    
				AND NOT EXISTS ( SELECT 1     
						FROM dbo.GroupFunction AS gf WITH (NOLOCK)     
						WHERE gf.GroupId = gmt.NAPGroupId AND gf.FunctionId = f.FunctionId )    
		) AS t   
	GROUP BY
		t.NAPGroupId,    
		t.FunctionId,    
		t.SiteId 

	-- Update group permission 

	UPDATE gf
	SET gf.Policy = CASE gp.Policy    
						WHEN 0 THEN 0  -- None    
						WHEN 1 THEN 1  -- Read    
						ELSE CASE          
								WHEN f.CRUD = 0 THEN 1    
								WHEN f.CRUD = 1 THEN 2    
							END     
					END     
	FROM     
		dbo.GroupFunction AS gf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @CRMFunctionMappingTable AS fmt ON gf.FunctionId = fmt.NAPFunctionId    
		INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId    
		INNER JOIN @GroupMappingTable AS gmt ON gf.GroupID = gmt.NAPGroupId
		INNER JOIN DBPOLICY.bodb02.dbo.Acc_GroupPolicy_1 AS gp WITH (NOLOCK)   
			ON     
				gmt.AccountingGroupId = gp.GroupID    
				AND gp.FuncID = fmt.AccountingFunctionId      
	WHERE     
		(gf.Policy = 0 AND gp.Policy <> 0)     
		OR (gf.Policy = 1 AND gp.Policy <> 1)  
		OR (gf.Policy > 1 AND gp.Policy = 0)  
		OR (gf.Policy > 1 AND gp.Policy = 1 AND f.CRUD = 1)
	 
	-- Import users    

	INSERT INTO dbo.Users (    
		UserId,     
		GroupId,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT     
		m.CustID,    
		gmt.NAPGroupId,       
		0,     -- Created by    
		GETDATE(),    
		0,     -- Modified by    
		GETDATE()    
	FROM     
		(    
			SELECT DISTINCT CustID    
			FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
			WHERE     
				FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @CRMFunctionMappingTable)    
				AND Policy > 0
				AND CustId NOT IN ( SELECT UserId FROM dbo.Users WITH (NOLOCK) )    
		) AS m    
		INNER JOIN DBPOLICY.bodb02.dbo.accCustomer_1 AS c WITH (NOLOCK) ON m.CustID = c.custid    
		INNER JOIN @GroupMappingTable AS gmt ON c.GroupID = gmt.AccountingGroupId    

	-- Import user site    

	INSERT INTO UserSite (    
		UserId,    
		SiteId,    
		Level,    
		IsActive,    
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT     
		t.CustID,    
		@CRMSiteId,      
		0,      -- User    
		1,      -- IsActive    
		0,      -- CreatedBy    
		GETDATE(),    
		0,      -- ModifiedBy    
		GETDATE()    
	FROM     
		(    
			SELECT DISTINCT CustID    
			FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
			WHERE     
				FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @CRMFunctionMappingTable)    
				AND Policy > 0
				AND CustId NOT IN ( SELECT UserId     
									FROM dbo.UserSite WITH (NOLOCK)     
									WHERE SiteId = @CRMSiteId )    
		) AS t    

	-- Import user permission    

	INSERT INTO dbo.UserFunction (    
		UserId,     
		FunctionId,     
		SiteId,     
		Policy,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT    
		t.CustID,    
		t.FunctionId,    
		t.SiteId,    
		MAX(t.Policy),    
		0,   -- CreatedBy    
		GETDATE(),    
		0,   -- ModifiedBy    
		GETDATE()    
	FROM    
		(    
			SELECT DISTINCT     
				mp.CustID,    
				f.FunctionId,    
				@CRMSiteId AS SiteId,        
				CASE     
					WHEN us.Level >= 50 THEN CASE      -- Site Admin     
						WHEN f.CRUD = 0 THEN 1    
						WHEN f.CRUD = 1 THEN 2    
						END      
					ELSE CASE mp.Policy    
							WHEN 0 THEN 0  -- None    
							WHEN 1 THEN 1  -- Read    
							ELSE CASE          
									WHEN f.CRUD = 0 THEN 1    
									WHEN f.CRUD = 1 THEN 2    
								END      
					END    
				END AS Policy    
			FROM     
				DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 AS mp WITH (NOLOCK)    
				INNER JOIN @CRMFunctionMappingTable AS fmt ON mp.FuncID = fmt.AccountingFunctionId    
				INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
				INNER JOIN dbo.UserSite AS us WITH (NOLOCK)     
					ON     
					mp.CustID = us.UserId    
					AND us.SiteId = @CRMSiteId    
			WHERE     
				mp.FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @CRMFunctionMappingTable )    
				AND NOT EXISTS (	SELECT 1 FROM dbo.UserFunction AS uf WITH (NOLOCK)   
									WHERE uf.UserId = mp.CustID AND uf.FunctionId = f.FunctionId )    
		) AS t     
	GROUP BY
		t.CustID,    
		t.FunctionId,    
		t.SiteId 

	-- Update user permission    

	UPDATE uf    
	SET uf.Policy = CASE temp.MaxPolicy    
						WHEN 0 THEN 0  -- None    
						WHEN 1 THEN 1  -- Read    
						ELSE CASE          
								WHEN temp.CRUD = 0 THEN 1    
								WHEN temp.CRUD = 1 THEN 2    
							END     
					END     
	FROM     		
		dbo.UserFunction AS uf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN
			(
				SELECT    
					uf.UserId,
					uf.FunctionId,
					us.Level,					
					f.CRUD,
					MAX(mp.Policy) AS MaxPolicy
				FROM 
					dbo.UserFunction AS uf WITH (NOLOCK)
					INNER JOIN @CRMFunctionMappingTable AS fmt ON uf.FunctionId = fmt.NAPFunctionId    
					INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
					INNER JOIN dbo.UserSite AS us     
						ON     
							uf.UserId = us.UserId    
							AND us.SiteId = @CRMSiteId    
					INNER JOIN DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 AS mp WITH (NOLOCK)  
						ON     
							uf.UserId = mp.CustID    
							AND mp.FuncID = fmt.AccountingFunctionId    
				GROUP BY
					uf.UserId,
					uf.FunctionId,
					us.Level,					
					f.CRUD
			) AS temp
		ON uf.FunctionId = temp.FunctionId AND uf.UserId = temp.UserId
	WHERE     
		temp.Level = 0 -- User    
		AND ((uf.Policy = 0 AND temp.MaxPolicy <> 0)     
		OR (uf.Policy = 1 AND temp.MaxPolicy <> 1)  
		OR (uf.Policy > 1 AND temp.MaxPolicy = 0)  
		OR (uf.Policy > 1 AND temp.MaxPolicy = 1 AND temp.CRUD = 1))     
*/
	-- End CRM

	-- Begin IMS

	-- Data preparation    

	DECLARE @IMSFunctionMappingTable TABLE (    
		NAPFunctionId			INT,    
		AccountingFunctionId	INT)    

	--  Local test    
	--INSERT INTO @IMSFunctionMappingTable (NAPFunctionId, AccountingFunctionId)    
	--SELECT 720, 296	UNION ALL	-- LicenseeBilling 
	--SELECT 718, 296	UNION ALL	-- Report 
	--SELECT 721, 296	UNION ALL	-- ManageInvoice 
	--SELECT 719, 296				-- Invoice 

	-- Production    

	INSERT INTO @IMSFunctionMappingTable (NAPFunctionId, AccountingFunctionId)    
	SELECT 636, 296	UNION ALL	-- LicenseeSettlement 
	SELECT 635, 296	UNION ALL	-- Report 
	SELECT 714, 296	UNION ALL	-- CreateInvoice 
	SELECT 713, 296				-- Invoice 

/*
	-- Import group permission    
	
	INSERT INTO dbo.GroupFunction (    
		GroupId,     
		FunctionId,     
		SiteId,     
		Policy,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT    
		t.NAPGroupId,    
		t.FunctionId,    
		t.SiteId,    
		MAX(t.Policy),   
		0,   -- CreatedBy    
		GETDATE(),    
		0,   -- ModifiedBy    
		GETDATE()    
	FROM    
		(    
			SELECT DISTINCT     
				gmt.NAPGroupId,    
				f.FunctionId,    
				@IMSSiteId AS SiteId,        
				CASE gp.Policy    
					WHEN 0 THEN 0  -- None    
					WHEN 1 THEN 1  -- Read    
					ELSE CASE          
							WHEN f.CRUD = 0 THEN 1    
							WHEN f.CRUD = 1 THEN 2    
						END      
				END AS Policy    
			FROM     
				DBPOLICY.bodb02.dbo.Acc_GroupPolicy_1 AS gp WITH (NOLOCK)    
				INNER JOIN @IMSFunctionMappingTable AS fmt ON gp.FuncID = fmt.AccountingFunctionId    
				INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
				INNER JOIN @GroupMappingTable AS gmt ON gp.GroupID = gmt.AccountingGroupId
			WHERE     
				gp.FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @IMSFunctionMappingTable )    
				AND NOT EXISTS ( SELECT 1     
						FROM dbo.GroupFunction AS gf WITH (NOLOCK)     
						WHERE gf.GroupId = gmt.NAPGroupId AND gf.FunctionId = f.FunctionId )    
		) AS t   
	GROUP BY
		t.NAPGroupId,    
		t.FunctionId,    
		t.SiteId 

	-- Update group permission 

	UPDATE gf
	SET gf.Policy = CASE gp.Policy    
						WHEN 0 THEN 0  -- None    
						WHEN 1 THEN 1  -- Read    
						ELSE CASE          
								WHEN f.CRUD = 0 THEN 1    
								WHEN f.CRUD = 1 THEN 2    
							END     
					END     
	FROM     
		dbo.GroupFunction AS gf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @IMSFunctionMappingTable AS fmt ON gf.FunctionId = fmt.NAPFunctionId    
		INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId    
		INNER JOIN @GroupMappingTable AS gmt ON gf.GroupID = gmt.NAPGroupId
		INNER JOIN DBPOLICY.bodb02.dbo.Acc_GroupPolicy_1 AS gp WITH (NOLOCK)   
			ON     
				gmt.AccountingGroupId = gp.GroupID    
				AND gp.FuncID = fmt.AccountingFunctionId      
	WHERE     
		(gf.Policy = 0 AND gp.Policy <> 0)     
		OR (gf.Policy = 1 AND gp.Policy <> 1)  
		OR (gf.Policy > 1 AND gp.Policy = 0)  
		OR (gf.Policy > 1 AND gp.Policy = 1 AND f.CRUD = 1)
	 
	-- Import users    

	INSERT INTO dbo.Users (    
		UserId,     
		GroupId,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT     
		m.CustID,    
		gmt.NAPGroupId,       
		0,     -- Created by    
		GETDATE(),    
		0,     -- Modified by    
		GETDATE()    
	FROM     
		(    
			SELECT DISTINCT CustID    
			FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
			WHERE     
				FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @IMSFunctionMappingTable)    
				AND Policy > 0
				AND CustId NOT IN ( SELECT UserId FROM dbo.Users WITH (NOLOCK) )    
		) AS m    
		INNER JOIN DBPOLICY.bodb02.dbo.accCustomer_1 AS c WITH (NOLOCK) ON m.CustID = c.custid    
		INNER JOIN @GroupMappingTable AS gmt ON c.GroupID = gmt.AccountingGroupId    

	-- Import user site    

	INSERT INTO UserSite (    
		UserId,    
		SiteId,    
		Level,    
		IsActive,    
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT     
		t.CustID,    
		@IMSSiteId,      
		0,      -- User    
		1,      -- IsActive    
		0,      -- CreatedBy    
		GETDATE(),    
		0,      -- ModifiedBy    
		GETDATE()    
	FROM     
		(    
			SELECT DISTINCT CustID    
			FROM DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 WITH (NOLOCK)    
			WHERE     
				FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @IMSFunctionMappingTable)    
				AND Policy > 0
				AND CustId NOT IN ( SELECT UserId     
									FROM dbo.UserSite WITH (NOLOCK)     
									WHERE SiteId = @IMSSiteId )    
		) AS t    

	-- Import user permission    

	INSERT INTO dbo.UserFunction (    
		UserId,     
		FunctionId,     
		SiteId,     
		Policy,     
		CreatedBy,     
		CreatedDate,     
		ModifiedBy,     
		ModifiedDate)    
	SELECT    
		t.CustID,    
		t.FunctionId,    
		t.SiteId,    
		MAX(t.Policy),    
		0,   -- CreatedBy    
		GETDATE(),    
		0,   -- ModifiedBy    
		GETDATE()    
	FROM    
		(    
			SELECT DISTINCT     
				mp.CustID,    
				f.FunctionId,    
				@IMSSiteId AS SiteId,        
				CASE     
					WHEN us.Level >= 50 THEN CASE      -- Site Admin     
						WHEN f.CRUD = 0 THEN 1    
						WHEN f.CRUD = 1 THEN 2    
						END      
					ELSE CASE mp.Policy    
							WHEN 0 THEN 0  -- None    
							WHEN 1 THEN 1  -- Read    
							ELSE CASE          
									WHEN f.CRUD = 0 THEN 1    
									WHEN f.CRUD = 1 THEN 2    
								END      
					END    
				END AS Policy    
			FROM     
				DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 AS mp WITH (NOLOCK)    
				INNER JOIN @IMSFunctionMappingTable AS fmt ON mp.FuncID = fmt.AccountingFunctionId    
				INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
				INNER JOIN dbo.UserSite AS us WITH (NOLOCK)     
					ON     
					mp.CustID = us.UserId    
					AND us.SiteId = @IMSSiteId    
			WHERE     
				mp.FuncID IN ( SELECT DISTINCT AccountingFunctionId FROM @IMSFunctionMappingTable )    
				AND NOT EXISTS (	SELECT 1 FROM dbo.UserFunction AS uf WITH (NOLOCK)   
									WHERE uf.UserId = mp.CustID AND uf.FunctionId = f.FunctionId )    
		) AS t     
	GROUP BY
		t.CustID,    
		t.FunctionId,    
		t.SiteId 

	-- Update user permission    

	UPDATE uf    
	SET uf.Policy = CASE temp.MaxPolicy    
						WHEN 0 THEN 0  -- None    
						WHEN 1 THEN 1  -- Read    
						ELSE CASE          
								WHEN temp.CRUD = 0 THEN 1    
								WHEN temp.CRUD = 1 THEN 2    
							END     
					END     
	FROM     		
		dbo.UserFunction AS uf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN
			(
				SELECT    
					uf.UserId,
					uf.FunctionId,
					us.Level,					
					f.CRUD,
					MAX(mp.Policy) AS MaxPolicy
				FROM 
					dbo.UserFunction AS uf WITH (NOLOCK)
					INNER JOIN @IMSFunctionMappingTable AS fmt ON uf.FunctionId = fmt.NAPFunctionId    
					INNER JOIN dbo.Functions AS f WITH (NOLOCK) ON fmt.NAPFunctionId = f.FunctionId    
					INNER JOIN dbo.UserSite AS us     
						ON     
							uf.UserId = us.UserId    
							AND us.SiteId = @IMSSiteId    
					INNER JOIN DBPOLICY.bodb02.dbo.Acc_MemberPolicy_1 AS mp WITH (NOLOCK)  
						ON     
							uf.UserId = mp.CustID    
							AND mp.FuncID = fmt.AccountingFunctionId    
				GROUP BY
					uf.UserId,
					uf.FunctionId,
					us.Level,					
					f.CRUD
			) AS temp
		ON uf.FunctionId = temp.FunctionId AND uf.UserId = temp.UserId
	WHERE     
		temp.Level = 0 -- User    
		AND ((uf.Policy = 0 AND temp.MaxPolicy <> 0)     
		OR (uf.Policy = 1 AND temp.MaxPolicy <> 1)  
		OR (uf.Policy > 1 AND temp.MaxPolicy = 0)  
		OR (uf.Policy > 1 AND temp.MaxPolicy = 1 AND temp.CRUD = 1))     

	-- End IMS
*/

END
