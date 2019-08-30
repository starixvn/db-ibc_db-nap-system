/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetRestriction_SettingSel] (
	@SportType	SMALLINT = 1,
	@IsTest		BIT = 0
)
AS
/*
	Created: 20190829@Eden
	Task : Get Bet Restriction Setting for ON/OFF 
	DB: DBACC/bodb02
	Original:

	Revisions:  
	- 20190829@Eden: Create New SP  [RedmineID: #117727]

	Example: 
	EXEC NAP_BetRestriction_SettingSel 
		@SportType = 1,
		@IsTest= 0

	*/
BEGIN
	SELECT	SettingID,
			SportType,
			RestrictionLevel,
			IsLicensee,
			LiveBetAcceptStatus,
			SeizeBetTicketStatus,
			BetLimitStatus
	FROM	BetRestriction_Setting bs WITH(NOLOCK) 
	WHERE  	1 = CASE WHEN BackEndStatus <=  @IsTest THEN 1 ELSE 0 END
		    AND SportType = @SportType 
END
GO


