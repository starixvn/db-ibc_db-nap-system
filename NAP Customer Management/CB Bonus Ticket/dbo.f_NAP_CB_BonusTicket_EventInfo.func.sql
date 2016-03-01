USE [bodb02]
GO
/****** Object:  UserDefinedFunction [dbo].[f_ParseTransDesc]    Script Date: 2/15/2016 4:04:02 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[f_NAP_CB_BonusTicket_EventInfo]
(
	@TransDesc 	NVARCHAR(1000)
)  
RETURNS @OutputTable TABLE(choice NVARCHAR(50), league NVARCHAR(250), match NVARCHAR(250), result NVARCHAR(50) )
AS  
/*
Created: 20140306@bobby
Task : 

DB: DBACC/bodb02
Revisions:
	
Paramters Explanation:
	@TransDesc = 'choice=1-1;league=sasas asas;match=A vs B;result=0-0;ip=127.0.0.1'

*/

BEGIN 

	IF @TransDesc IS NULL OR @TransDesc = ''
		RETURN
	
	DECLARE @Separate CHAR(1) = ';'

		
	DECLARE @choice VARCHAR(100)
		, @league	VARCHAR(300)
		, @match	VARCHAR(300)
		, @result	VARCHAR(100)

	;WITH Pieces([Index], Start, [Stop])
	AS 
	(
		SELECT 1, 1, CHARINDEX(@Separate, @TransDesc)

		UNION ALL
			
		SELECT [Index] + 1, [Stop] + 1, CHARINDEX(@Separate, @TransDesc, [Stop] + 1)
		FROM Pieces	WHERE [Stop] > 0
	)
	--select * FROM Pieces
	SELECT @choice = case when [index] = 1 then SUBSTRING(@TransDesc, Start, [Stop] - Start) else @choice end
		,@league = case when [index] = 2 then SUBSTRING(@TransDesc, Start, [Stop] - Start) else @league end
		,@match = case when [index] = 3 then SUBSTRING(@TransDesc, Start, [Stop] - Start) else @match end
		,@result = case when [index] = 4 then SUBSTRING(@TransDesc, Start, [Stop] - Start) else @result end
	FROM Pieces

	

	INSERT INTO @OutputTable(choice, league, match, result)
	(
		SELECT SUBSTRING(@choice, charindex('=', @choice)+1, 50) as choice
			,SUBSTRING(@league, charindex('=', @league)+1, 250) as league
			,SUBSTRING(@match, charindex('=', @match)+1, 250) as match
			,SUBSTRING(@result, charindex('=', @result)+1, 50) as result
	)
	RETURN
END
go
select *
from [dbo].[f_NAP_CB_BonusTicket_EventInfo]('choice=1-1;league=sasas asas;match=A vs B;result=10-10;ip=127.0.0.1')