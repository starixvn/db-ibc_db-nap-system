/*<info serverAlias="DBAGE-bodb02" executers="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE[sb].[DBA_ConversationManagement]

		@FunctionName VARCHAR(100)
	,	@ContractName VARCHAR(100)  
	,	@FromService VARCHAR(100)
	,	@ToService VARCHAR(100)
	,	@Coversation_number INT
	,	@Mode VARCHAR (50) ='AddNew'  
AS/*

	Create By: 20181227@Helen
	Task: ServiceBroker Consersation troubleshoot
	DB: ServiceBrokerDB
	Revisions:
		- 20190708@Patrick: Move to DB052 - [Redmine:#112219]
	
	Para's explaination

		- @Coversation_number: number of conversation will be create
		- @Mode: 'AddNew' , 'Reset' 
*/
BEGIN 

	SET NOCOUNT ON 

	DECLARE @Cnt INT
		  , @i INT
		  , @handle UNIQUEIDENTIFIER
		  , @ConversationNo INT
		  , @SendSequence BIGINT
		  , @CurrentSendSequence BIGINT		  
		  , @CurrentDate DATETIME		  
		  , @MaxID INT			  

	DECLARE @ErrorMessage NVARCHAR(4000) 
		  , @ErrorSeverity INT
		  , @ErrorState INT		  

	SELECT @ErrorSeverity = 10, @ErrorState = 1, @CurrentDate = GETDATE()							 

	SET @Cnt = (SELECT Cnt
				FROM sb.ConversationCount WITH (NOLOCK)
				WHERE FunctionName = @functionName
						AND ContractName = @contractName)
	IF @Cnt IS NULL 
	BEGIN
		INSERT INTO sb.ConversationCount (functionName,ContractName,Cnt) 
		VALUES (@functionName,@contractName,0)
		SET @Cnt = 0

	END
	
	IF @Mode = 'AddNew'
	BEGIN
		SET @i = 1

		WHILE @i <= @Coversation_number
		BEGIN
			BEGIN DIALOG CONVERSATION @handle
			FROM SERVICE  @fromService 
			TO SERVICE  @toService 
			on contract @contractName 
			WITH ENCRYPTION = OFF								
			
			SET @Cnt = @Cnt + 1
	
			INSERT INTO sb.ConversationManagement(FunctionName, ContractName, ConversationNo, ConversationHandle,CreatedDate,IsValid)
			VALUES(@functionName, @contractName, @Cnt, @handle,@CurrentDate,1)

			SET @i = @i + 1	
						
		END
	
		UPDATE sb.ConversationCount WITH (ROWLOCK)
			SET Cnt = @Cnt
		WHERE FunctionName = @functionName
		  AND ContractName = @contractName
  
	END

	IF @Mode = 'Reset'
	BEGIN

		--#1 - CLEAN ALL CONVERSATION
		CREATE TABLE #Temp (ID INT IDENTITY (1,1), handle UNIQUEIDENTIFIER)

		DECLARE @start INT , @End INT 

		INSERT INTO #Temp (handle)
		SELECT e.conversation_handle
		FROM sys.conversation_endpoints e WITH(NOLOCK)
			INNER JOIN sys.services s WITH(NOLOCK) on e.service_id = s.service_id
			INNER JOIN sys.service_contracts sc WITH (NOLOCK) ON sc.service_contract_id = e.service_contract_id AND sc.name = @ContractName
		WHERE s.name IN (@FromService,@ToService)

		SET @start = 1

		SET @End = (SELECT MAX(ID) FROM #Temp)

		WHILE @start <= @End
		BEGIN
			SET @handle = (SELECT handle FROM #Temp WHERE ID = @start)
			
			IF @handle IS NOT NULL
				END CONVERSATION @handle WITH CLEANUP
			
			SET @start = @start + 1
		END
		
		DELETE sb.ConversationManagement WHERE FunctionName = @functionName  AND ContractName = @contractName

		--- #2 - INSERT NEW

		SET @i = 1
		SET @Cnt = 0
		WHILE @i <= @Coversation_number
		BEGIN

			BEGIN DIALOG CONVERSATION @handle
			FROM SERVICE  @fromService 
			TO SERVICE  @toService 
			on contract @contractName 
			WITH ENCRYPTION = OFF								

			SET @Cnt = @Cnt + 1

			INSERT INTO sb.ConversationManagement(FunctionName, ContractName, ConversationNo, ConversationHandle,CreatedDate,IsValid)
			VALUES(@functionName, @contractName, @Cnt, @handle,@CurrentDate,1)

			SET @i = @i + 1					
		END

		UPDATE sb.ConversationCount WITH (ROWLOCK)
			SET Cnt = @Cnt
		WHERE FunctionName = @functionName
		  AND ContractName = @contractName

	END
	
END
