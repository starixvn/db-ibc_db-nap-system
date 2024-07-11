/*<info serverAlias="DBPOL-NAP_UserControl" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_Admin_GetOTP] @CustID INT         = 0, 
                                         @System VARCHAR(10) = ''
AS

/*  
 Created: 20220517@Winfred  
 Task : NAP OTP Login requried for VPN's users  
 DB: DBPOL/NAP_UserControl  
 Original:  
  
 Revisions:  
     - 20220517@Winfred: Get OTP Login requried for VPN's users [redmine:170994]  
     - 20240701@Jacob: Implement Data Caching - [Redmine:207784]
 Param's Explanation:  
*/

    BEGIN
        SET NOCOUNT ON;
        SELECT @CustID = ISNULL(@CustId, 0), 
               @System = ISNULL(@System, '');
        -- Get OTP admin  
        SELECT a.CustID, 
               c.username, 
               a.SecretKey, 
               a.IgnoreOTP, 
               a.[System], 
               a.Creator, 
               (CASE
                    WHEN ci.closed = 0
                    THEN 'Active'
                    ELSE 'Closed'
                END) AS [Status], 
               c.roleid
        FROM AdminOTP AS a WITH(NOLOCK)
             INNER JOIN CustDB.dbo.Customer AS c WITH(NOLOCK) ON a.custid = c.custid
             INNER JOIN CustDB.dbo.Custinfo AS ci WITH(NOLOCK) ON a.custid = ci.custid
        WHERE(@CustID = 0
              OR a.CustID = @CustID)
             AND (@System = ''
                  OR [System] = @System);
    END;

