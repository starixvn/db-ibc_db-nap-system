/*<info serverAlias="DBCUST-CustDB" executers="" isFunction="0"></info>*/
/*
    Created: 20240408@July
	Task: SMA TO Control - Prepare Setting for EC 2024 - [Redmine: #200069]
	DB: DBCUST-CustDB

*/

USE CustDB 
GO

--STEP 1: Get maxcustid from dbo.TOControl_GlobalSetting 
DECLARE @maxCustID INT 
SET @maxCustID = (SELECT MAX(CustID) FROM dbo.TOControl_GlobalSetting WITH (NOLOCK))
SELECT @maxCustID AS MAXCustID


--STEP 2: Script to save all current data into new physical TOControl_GlobalSetting-> TOControl_GlobalSetting_History_tmp
CREATE TABLE [dbo].[TOControl_GlobalSetting_History_tmp](
	[CustID] [int] NOT NULL,
	[MaxTurnOver] [money] NOT NULL,
	[Sporttype] [smallint] NOT NULL,
	[IsGroupHeadLine] [bit] NOT NULL,
	[ProfileID] [smallint] NOT NULL,
	[IsGlobalLockTOLimit] [bit] NULL,
 CONSTRAINT [PK_TO_ControlGlobalSetting_History_tmp] PRIMARY KEY CLUSTERED 
(
	[CustID] ASC,
	[Sporttype] ASC,
	[IsGroupHeadLine] ASC,
	[ProfileID] ASC
)
) ON [DATA]

ALTER TABLE [dbo].[TOControl_GlobalSetting_History_tmp] ADD  DEFAULT ((0)) FOR [IsGlobalLockTOLimit]


--STEP 3: Script backup to save all current data into new physical TOControl_GlobalSetting-> TOControl_GlobalSetting_History_tmp

CREATE TABLE #tblTOControl_GlobalSetting
(
	CustID INT,
	MaxTurnOver MONEY,
	Sporttype SMALLINT,
	IsGroupHeadLine BIT,
	ProfileID SMALLINT,
	IsGlobalLockTOLimit BIT,
	IsFinishHistory BIT,

)
CREATE CLUSTERED INDEX CIX_tblTOControl_GlobalSetting ON #tblTOControl_GlobalSetting (CustID, Sporttype, IsGroupHeadLine, ProfileID)

INSERT INTO #tblTOControl_GlobalSetting (CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit)
SELECT CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit
FROM dbo.TOControl_GlobalSetting s WITH(NOLOCK)
WHERE s.CustID <= @maxCustID

WHILE (1=1)
BEGIN

	UPDATE TOP(5000) t
			SET IsFinishHistory = 1
	OUTPUT DELETED.CustID
		 , DELETED.MaxTurnOver
		 , DELETED.Sporttype
		 , DELETED.IsGroupHeadLine
		 , DELETED.ProfileID
		 , DELETED.IsGlobalLockTOLimit
	INTO dbo.TOControl_GlobalSetting_History_tmp (CustID, MaxTurnOver, Sporttype, IsGroupHeadLine, ProfileID, IsGlobalLockTOLimit)
	FROM #tblTOControl_GlobalSetting t 
		WHERE IsFinishHistory IS NULL

	IF @@ROWCOUNT = 0 BREAK
END

DROP TABLE #tblTOControl_GlobalSetting
GO

