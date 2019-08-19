/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_ValidateSite] (
	  @SiteID			INT
	 ,@SportType		SMALLINT = 1
	 ,@IsAllowInsert	BIT = 0 OUTPUT
)
AS
/*
	Created: 20190815@Eden
	Task : Check exists Bet Restriction Site
	DB: DBACC/bodb02
	Original:

	Revisions:  
	- 20190815@Eden: Create New SP  [RedmineID: #117727]

	Parameter explanation:
	@IsAllowInsert =: 
			0 : Validate failed , existing record
			1 : succeed , can be inserted

	Example: 
	DECLARE @IsAllowInsert BIT 
	EXEC NAP_BetRestriction_ValidateSite
		@SiteID = 1, @SportType = 1,
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


