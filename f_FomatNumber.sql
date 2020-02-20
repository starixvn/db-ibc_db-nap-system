/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,Dot_Member" viewers="" isFunction="1"></info>*/

ALTER FUNCTION f_FomatNumber(@str VARCHAR(50)) 
RETURNS VARCHAR(50) 
AS
/*
    Created: Elodie
    Date: 20200210
    Task: Format number to write log
    DB: DBCUST/CustDB
    Original versions:                
    Revision:
		- 20200210@Elodie: Initial SP [Redmine: #127446]
    Example:
		SELECT dbo.f_FomatNumber ('0.00')
*/
BEGIN
	DECLARE @iDot TINYINT, @iCut TINYINT, @LenStr TINYINT

	SELECT @iDot = CHARINDEX('.',@str)
	SELECT @LenStr = LEN(@str)

	IF @iDot > 0
	BEGIN		
		SELECT @iCut = @LenStr - PATINDEX('%[123456789]%', REVERSE(@str)) + 1
		IF @iCut < @iDot OR @iCut > @LenStr
		BEGIN
			SELECT @str = SUBSTRING(@str,1,@iDot - 1)
		END
		ELSE
		BEGIN
			SELECT @str = SUBSTRING(@str,1,@iCut)
		END
	END	

	RETURN @str
END

