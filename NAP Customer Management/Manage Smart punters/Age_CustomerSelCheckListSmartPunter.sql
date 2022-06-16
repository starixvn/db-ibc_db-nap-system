/*<info serverAlias="DBCUST-CUSTDB" executers="bodbDownlineNet,bodbdownlinenetview" viewers="" isFunction="0" isNested="0" ></info>*/

ALTER PROCEDURE [dbo].Age_CustomerSelCheckListSmartPunter
	@ListUserName		VARCHAR(MAX),	
	@UserId				INT=0,
	@IsRestricted		BIT=0,
	@ActionID			INT=0,
	@IP					VARCHAR(15)=NULL 
AS
/*
	Created: Winnie
	Date: 2016-12-01
	DB: DBCUST.CustDB
	Task: Check a list customer is smart punter or not RedmineID: #67772
	Revisions:  		
		- 20220613@Elodie: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831]  
*/
 BEGIN
    SET nocount ON

    DECLARE 
            @UplineId INT,
            @CustId   INT,
            @tmpListUserName VARCHAR(MAX)

    CREATE TABLE #username
      (
         username     VARCHAR(50),
         custid       INT,
         roleid       INT,
         recommend    INT,
         mrecommend   INT,
         srecommend   INT,
         issmarpunter BIT,
         uplineid     INT
      )


    INSERT #username (username)     
    SELECT value FROM string_split(@ListUserName,',') where value <> ''

    UPDATE u
    SET    custid = c.custid,
           roleid = c.roleid,
           recommend = c.recommend,
           mrecommend = c.mrecommend,
           srecommend = c.srecommend
    FROM   #username u
           INNER JOIN customer c WITH(nolock) ON u.username = c.username

    UPDATE u
    SET    issmarpunter = 1
    FROM   #username u
           INNER JOIN smartpunterlist c WITH(nolock)  ON u.custid = c.custid

    UPDATE u
    SET    issmarpunter = 1,
           uplineid = recommend
    FROM   #username u
           INNER JOIN smartpunterlist c WITH(nolock)  ON u.recommend = c.custid
    WHERE  issmarpunter IS NULL

    UPDATE u
    SET    issmarpunter = 1,
           uplineid = mrecommend
    FROM   #username u
           INNER JOIN smartpunterlist c WITH(nolock)   ON u.mrecommend = c.custid
    WHERE  issmarpunter IS NULL

    UPDATE u
    SET    issmarpunter = 1,
           uplineid = srecommend
    FROM   #username u
           INNER JOIN smartpunterlist c WITH(nolock)    ON u.srecommend = c.custid
    WHERE  issmarpunter IS NULL
   
	SELECT @tmpListUserName=STUFF((Select ','+ t1.username
				from  #username  T1 WITH(NOLOCK)
				where T1.issmarpunter=1
				FOR XML PATH('')),1,1,'') 

	IF ( @ActionID <> 0 )
      BEGIN
			IF (@tmpListUserName<>'')
			
				  EXEC dblog.bodb_customerlog.dbo.Age_userlog_smartpunterinsmultiple
					@Userid = @userid,
					@ListUserName = @tmpListUserName,
					@ActionID = @ActionID,
					@IP = @IP,
					@IsRestricted = @IsRestricted
			
			ELSE
					EXEC dblog.bodb_customerlog.dbo.NAP_UserLog_SmartPunterIns
					@Userid = @userid,
					@CustId = NULL,
					@ActionID = @ActionID,
					@IP = @IP,
					@IsRestricted = @IsRestricted,
					@UplineId=NULL
      END
END  
GO
