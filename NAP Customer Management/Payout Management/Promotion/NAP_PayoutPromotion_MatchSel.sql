/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_PayoutPromotion_MatchSel]     
     @TypeID	TINYINT=0
	,@MatchID	INT=0
AS    
/*    
    Created by: Tacy@20240328
    Task : Get Payout Promotion List
    DB: DBACC/bodb02    
    
	Revisions:
        - 20240328@Tacy: NAP CM - Correct Score Promotion [redmine: #202974]
		- 20240514@Tacy: NAP CM - Get match14 and match_bk [redmine: #205071]

	Param's Explanation:
		* @TypeID :	1 ~ Correct Score Lucky Draw
					2 ~ 6 Scores EC24 Challenge
*/    
BEGIN    
    SET NOCOUNT ON;

	IF @TypeID = 1	BEGIN		;WITH tmpLuckyDrawList AS (			SELECT DISTINCT				l.matchid				, l.TypeID			FROM LuckyDrawList l WITH (NOLOCK)			WHERE l.TypeID = 1 AND l.IsLicensee=0			AND (l.matchid=@MatchID OR @MatchID=0)		)		SELECT l.matchid			, a.teamname home			, b.teamname away			, l.TypeID		FROM tmpLuckyDrawList l		CROSS APPLY (				SELECT TOP 1 m.matchid, M.homeid, m.awayid												FROM match m WITH (NOLOCK) 			WHERE m.matchid	 = l.matchid			UNION															SELECT TOP 1 m.matchid, M.homeid, m.awayid			FROM match14 m WITH (NOLOCK) 			WHERE m.matchid	 = l.matchid				UNION			SELECT TOP 1 m.matchid, M.homeid, m.awayid														FROM bodb_archive.dbo.match_bk m WITH (NOLOCK) 			WHERE m.matchid	 = l.matchid													) AS tmp			INNER JOIN team a WITH (NOLOCK) ON tmp.homeid=a.teamid			INNER JOIN team b WITH (NOLOCK) ON tmp.awayid=b.teamid	END	ELSE 	IF @TypeID = 2	BEGIN		SELECT DISTINCT 			l.matchid			, NULL home			, NULL away			, l.TypeID		FROM LuckyDrawList l WITH (NOLOCK)		WHERE l.TypeID = 2 AND l.IsLicensee=0		AND (l.matchid=@MatchID OR @MatchID=0)	ENDEND
GO