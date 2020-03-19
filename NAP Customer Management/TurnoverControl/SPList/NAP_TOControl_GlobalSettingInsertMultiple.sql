/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_GlobalSettingInsertMultiple]
(	
	@GlobalSetting VARCHAR(MAX) = ''
	, @UserID INT
	, @IP	VARCHAR(40)
	, @ErrCode INT = 0 OUTPUT
	, @ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS

/*
	Created: Helen
	Date: 2017-09-20
	Task: Insert new CustId to Gobal setting (multiple insert)
	DB: DBCUST.CustDB

	Revisions:
		- 20171115@Vicky: change location check permission [RedmineID: #86455]
		- 20171215@Helen: Implement some change request from OPS Team - [Redmine: 85638]
		- 20190102@Malcolm: Separate setting and notification into Live/Non-Live and bettypes [Redmine : 125076]
		
	Parameter's explaination:
		Sample data for @GlobalSetting: 
		'<ROOT>
			<gs us="super01" isGH="1" maxTO="100" spt = "1" pfID = "1"/>
			<gs us="super02" isGH="0" maxTO="1" spt = "1" pfID = "2"/>
		</ROOT>'
*/
BEGIN 
	SET NOCOUNT ON

	CREATE TABLE #GlobalSettingTbl (ID INT IDENTITY(1,1) PRIMARY KEY, Username NVARCHAR(50), IsGroupHeadline BIT, MaxTurnover MONEY, SportType SMALLINT, ProfileID SMALLINT)
	
	CREATE TABLE #ExistingGlobalSettingTbl (ID INT IDENTITY(1,1) PRIMARY KEY, CustID INT, IsGroupHeadline BIT, MaxTurnover MONEY, SportType SMALLINT, ProfileID SMALLINT)
	
	CREATE TABLE #InsertNewGlobalSettingTbl (ID INT IDENTITY(1,1) PRIMARY KEY, Username NVARCHAR(50), IsGroupHeadline BIT, MaxTurnover MONEY, SportType SMALLINT, GlobalSetting NVARCHAR(MAX))
	
	--Parse XML	
	DECLARE @iDoc INT, @start INT, @end INT, @UserName NVARCHAR(50), @MaxTurnover MONEY, @IsGroupHeadline BIT, @SportType SMALLINT, @CustID INT, @GlobalSettingSub NVARCHAR(MAX), @ProfileID SMALLINT
	
	SET @start = 1
	SET @UserName = ''
	SET @MaxTurnover = 0 
	SET @IsGroupHeadline = 0
	SET @SportType = 1
	SET @GlobalSettingSub = ''
	
	EXEC sp_xml_preparedocument @iDoc OUTPUT, @GlobalSetting

	INSERT #GlobalSettingTbl (Username,IsGroupHeadline,MaxTurnover,SportType, ProfileID)
	SELECT us,isGH,maxTO,spt,pfID
	FROM OPENXML(@iDoc, '/ROOT/gs', 1) WITH (us NVARCHAR(50), isGH BIT, maxTO MONEY, spt SMALLINT, pfID SMALLINT)

	EXEC sp_xml_removedocument @iDoc	
	
	INSERT #InsertNewGlobalSettingTbl (Username,IsGroupHeadline,SportType, GlobalSetting)
	SELECT GS_tmp.Username,
	       GS_tmp.IsGroupHeadline,
		   GS_tmp.SportType, 
	      (SELECT GL.MaxTurnover,
		          GL.ProfileID 
		   FROM #GlobalSettingTbl AS gl WITH (NOLOCK) 
	       WHERE GL.Username = GS_tmp.Username AND gl.IsGroupHeadline = GS_tmp.IsGroupHeadline AND gl.SportType = GS_tmp.SportType  FOR XML RAW('GlobalSetting'), ROOT('ROOT')) AS GlobalSetting
	FROM #GlobalSettingTbl GS_tmp WITH (NOLOCK)
		INNER JOIN custInfo ci WITH (NOLOCK) ON GS_tmp.Username = ci.username
	WHERE NOT EXISTS (	SELECT 1 
						FROM dbo.TOControl_GlobalSetting GS WITH (NOLOCK) 
						WHERE gs.CustID = ci.custid 
							AND GS_tmp.SportType = GS.Sporttype 
							AND GS_tmp.IsGroupHeadline = GS.IsGroupHeadLine
							AND GS_tmp.ProfileID = GS.ProfileID
					)
	GROUP BY GS_tmp.Username, GS_tmp.IsGroupHeadline, GS_tmp.SportType
	
	INSERT #ExistingGlobalSettingTbl (CustID,IsGroupHeadline,MaxTurnover,SportType, ProfileID)
	SELECT ci.custid,IsGroupHeadline,MaxTurnover,SportType,ProfileID
	FROM #GlobalSettingTbl GS_tmp WITH (NOLOCK)
		INNER JOIN custInfo CI WITH (NOLOCK) ON GS_tmp.Username = CI.username
	WHERE EXISTS (	SELECT 1 
						FROM dbo.TOControl_GlobalSetting GS WITH (NOLOCK) 
						WHERE gs.CustID = CI.custid 
							AND GS_tmp.SportType = GS.Sporttype 
							AND GS_tmp.IsGroupHeadline = GS.IsGroupHeadLine
							AND GS_tmp.MaxTurnover <> GS.MaxTurnOver
					)
	
	
	-- Process for new
	IF EXISTS (SELECT 1 FROM #InsertNewGlobalSettingTbl)
	BEGIN
		SET @end = (SELECT MAX(ID) FROM #InsertNewGlobalSettingTbl WITH (NOLOCK))
		
		WHILE @start <= @end
		BEGIN
			SELECT @UserName = Username, @GlobalSettingSub = GlobalSetting, @MaxTurnover = MaxTurnover, @IsGroupHeadline = IsGroupHeadline, @SportType = SportType FROM #InsertNewGlobalSettingTbl WITH (NOLOCK) WHERE ID = @start
			
			EXEC dbo.NAP_TOControl_GlobalSettingInsert @UserID=@UserID,@IP=@IP,@UserName=@UserName,@GlobalSetting=@GlobalSettingSub,@IsGroupHeadline = @IsGroupHeadline,@SportType = @SportType,@ErrCode=@ErrCode output,@ErrMsg=@ErrMsg output
			
			IF @ErrCode <> 0 
				BREAK
			
			SET @start = @start + 1
		END
	END
		
	-- Process for update
	IF EXISTS (SELECT 1 FROM #ExistingGlobalSettingTbl WITH (NOLOCK))
	BEGIN
		SET @start = 1
		
		SET @end = (SELECT MAX(ID) FROM #ExistingGlobalSettingTbl WITH (NOLOCK))
		
		WHILE @start <= @end
		BEGIN
			SELECT @CustID = custid, @MaxTurnover = MaxTurnover, @IsGroupHeadline = IsGroupHeadline, @SportType = SportType, @ProfileID = ProfileID FROM #ExistingGlobalSettingTbl WITH (NOLOCK) WHERE ID = @start
				
			EXEC dbo.NAP_TOControl_GlobalSettingUpdate @CustID=@CustID,@UserID = @UserID,@IP=@IP,@MaxTurnover=@MaxTurnover, @ProfileID = @ProfileID, @IsGroupHeadline = @IsGroupHeadline,@SportType = @SportType,@ErrCode=@ErrCode output,@ErrMsg=@ErrMsg output
			
			IF @ErrCode <> 0 
				BREAK
			
			SET @start = @start + 1
		END			
	END
	
	DROP TABLE #ExistingGlobalSettingTbl
	DROP TABLE #GlobalSettingTbl
	DROP TABLE #InsertNewGlobalSettingTbl
	
END
GO

