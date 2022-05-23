/*<info serverAlias="DBPOL-NAP_UserControl" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_GetOTP]
	@CustID INT
AS

/*
	Created: 20220517@Winfred
	Task :	NAP OTP Login requried for VPN's users
	DB: DBPOL/NAP_UserControl
	Original:

	Revisions:
	    - 20220517@Winfred: Get OTP Login requried for VPN's users [redmine:170994]
	    
	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON    
	
   	-- Get OTP admin
	SELECT a.CustID,c.username,a.SecretKey,a.IgnoreOTP,a.System,a.Creator,(CASE WHEN ci.closed  = 0 THEN 'Active' ELSE 'Closed' END) AS [Status],c.roleid
	FROM AdminOTP AS a WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON a.custid = c.custid
		INNER JOIN CustDB.dbo.Custinfo AS ci WITH (NOLOCK) ON a.custid = ci.custid
	WHERE a.CustID = @CustID
		
END

