/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[BLC_SettingSelect_ByCust] 
	  @CustID		INT
AS
/*

	Created: 20200602@Eden
	Task : get bet limit control setting by Cust for SPU 
	DB: DBCUST-CUSTDB
	Original:

	Revisions:  
	- 20201005@Eden: Create New SP  [RedmineID: #141754]

	Parameter explanation:

	Example: 
	EXEC BLC_SettingSelect_ByCust 
		@CustID = 1176092
	*/
BEGIN 
	DECLARE @IsVIP BIT = 0
	SELECT @IsVIP = 1 
	FROM Dep_CustVIP vip WITH(NOLOCK) 
	WHERE vip.CustID = @CustID

	SELECT MIN(c.MaxBet) AS MaxBet,MIN(c.MaxPerMatch) AS MaxPerMatch, @IsVIP AS IsVIP
	FROM custinfo ci WITH(NOLOCK) 
		INNER JOIN BetLimitControlCustSetting c WITH(NOLOCK,FORCESEEK) ON c.CustID IN (ci.custid,ci.recommend,ci.mrecommend,ci.srecommend)
		INNER JOIN BetLimitControlType bt WITH(NOLOCK) ON c.BetLimitTypeID = bt.BetLimitTypeID
	WHERE ci.CustID = @CustID
			AND (@IsVIP = 0 OR bt.RestrictVIP = 1)
	OPTION (FORCE ORDER)
END
GO