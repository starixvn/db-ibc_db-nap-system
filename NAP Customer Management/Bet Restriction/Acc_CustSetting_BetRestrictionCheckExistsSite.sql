/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustSetting_BetRestrictionCheckExistsSite] (
	  @SiteID			INT
	 ,@SportType		SMALLINT = 1
	 ,@IsAllowInsert	BIT = 0 OUTPUT
)
AS
/*
	Created: 20190809@Eden
	Task : Check exists Bet Restriction Site
	DB: DBCUST/CustDB
	Original:

	Example: 
	DECLARE @IsAllowInsert BIT 
	EXEC Acc_CustSetting_BetRestrictionCheckExistsSite
		@SiteID = 234, 
		@IsAllowInsert = @IsAllowInsert OUTPUT
	SELECT @IsAllowInsert
	*/
BEGIN	
	IF EXISTS(	SELECT TOP 1 1 
				FROM BetRestriction_Site WITH(NOLOCK)
				WHERE SiteID = @SiteID AND SportType = @SportType )
		SET @IsAllowInsert = 0   
	ELSE
		SET @IsAllowInsert = 1
END
GO


