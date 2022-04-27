/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_TOControl_TurnoverNotificationUpdate]
(
	@matchids			VARCHAR(1000),
	@supers				VARCHAR(1000),
	@IsGroupHeadlines	VARCHAR(1000),
	@ProfileID          VARCHAR(1000),
	@nlevel				VARCHAR(4000),
	@ErrorCode			INT = 0 OUTPUT,
	@ErrorMessage		NVARCHAR(200) = '' OUTPUT
)
AS
/*
	Created: Don
	Date: 2017-03-24
	Task: Update isNotified after sending mail successfully
	DB: DBCUST.CustDB

	Revisions:
		- 20200114@Malcolm: Separate setting and notification into Live/Non-Live and bettypes [Redmine : #126348]
		- 20220427@July: SQL Server upgrade to 2019 phase 5 - Change STRING_SPLIT [Redmine: #171831]

	Parameter's explaination:
*/
BEGIN
	SET NOCOUNT ON 
	
	;WITH tmp AS
	(
		SELECT m.value AS matchid, c.value AS custid, l.value AS nlevel, h.value AS IsGroupHeadline, p.value AS ProfileID
		FROM (
			SELECT value, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [rank]
			FROM STRING_SPLIT(@matchids,',')
		)m
		INNER JOIN (
			SELECT value, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [rank]
			FROM STRING_SPLIT (@supers,',')
		)c ON m.[rank] = c.[rank]
		INNER JOIN (
			SELECT value, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [rank]
			FROM STRING_SPLIT (@IsGroupHeadlines,',')
		)h ON m.[rank] = h.[rank]
		INNER JOIN (
			SELECT value, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [rank]
			FROM STRING_SPLIT (@nlevel,',')
		)l ON m.[rank] = l.[rank]
		CROSS APPLY (
			SELECT value
			FROM STRING_SPLIT(@ProfileID,',') 
		)p
	)

	UPDATE t WITH(ROWLOCK,UPDLOCK)
	SET t.IsNotified = tmp.nlevel
	FROM dbo.TOControl_Setting t
		INNER JOIN tmp ON t.matchid = tmp.matchid AND t.custid = tmp.custid AND t.IsGroupHeadLine = tmp.IsGroupHeadline AND tmp.ProfileID = t.ProfileID
	
	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrorCode = 101,
				@ErrorMessage  = 'Update does not successfully.'
	END
END
GO

GRANT EXECUTE ON [dbo].[NAP_TOControl_TurnoverNotificationUpdate] TO [bodbAdminNet]
GO