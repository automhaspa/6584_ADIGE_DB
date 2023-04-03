SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_GestMsg_MoveItem_Completed]
@Id_Messaggio	Int
-- Parametri Standard;
,@Id_Processo		Varchar(30)	
,@Origine_Log		Varchar(25)	
,@Id_Utente			Varchar(32)		
,@Errore			Varchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	SET LOCK_TIMEOUT 5000

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @XmlMessage xml
		DECLARE @ErrorCode Int
		DECLARE @Esistenza_Parametro Bit
		DECLARE @ErrorCode_Desc Varchar(MAX)
		DECLARE @Cursore CURSOR
		DECLARE @Sequenza_Percorso Int
		DECLARE @MissionResult Bit
		DECLARE @Id_Missione Int
		DECLARE @MoveItem_Id Int
		
		-- Inserimento del codice;
		SELECT	@xmlMessage = Messaggio 
		FROM	Messaggi_Ricevuti
		WHERE	Id_Messaggio = @Id_Messaggio

		SET @MoveItem_Id = @XmlMessage.value('data(//MoveItemId)[1]','Int')	
		SET @ErrorCode = @XmlMessage.value('data(//ErrorCode)[1]','Int')	
		SET @MissionResult = @XmlMessage.value('data(//MissionResult)[1]','Bit')	
		
		-- Ricavo la posizione in cui mi trovo dal passo del percorso appena eseguito e i parametri della missione.
		SET @Cursore = CURSOR LOCAL STATIC FOR
		SELECT	Messaggi_Percorsi.Id_Percorso
				,Messaggi_Percorsi.Sequenza_Percorso
		FROM	Messaggi_Percorsi
		WHERE	Id_Messaggio = @MoveItem_Id			
				
		OPEN @Cursore	
		
		FETCH NEXT FROM @Cursore INTO
		@Id_Missione
		,@Sequenza_Percorso
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @MissionResult = 1
			BEGIN
				-- L'ErrorCode è nullo,quindi elimino l'xml Error della missione.
				WHILE ISNULL(@Esistenza_Parametro,0) = 1
				BEGIN
					SELECT	@Esistenza_Parametro = Xml_Param.exist('//Error')
					FROM	Missioni
					WHERE	Id_Missione = @Id_Missione

					IF @Esistenza_Parametro = 1
					BEGIN
						UPDATE	Missioni
						SET		Xml_Param.modify	('delete //Error[1]')
						WHERE	Id_Missione = @Id_Missione
					END
				END
				
				SET @Esistenza_Parametro = NULL

				WHILE	ISNULL(@Esistenza_Parametro,1) = 1
				BEGIN
					SELECT	@Esistenza_Parametro = Xml_Param.exist('//ErrorDesc')
					FROM	Missioni
					WHERE	Id_Missione = @Id_Missione

					IF @Esistenza_Parametro = 1
					BEGIN
						UPDATE	Missioni
						SET		Xml_Param.modify	('delete //ErrorDesc[1]')
						WHERE	Id_Missione = @Id_Missione
					END
				END		
				
				-- Non chiamo l'aggiorna posizione udc, teoricamente la missione non finirà mai con un move item.
				UPDATE	Percorso
				SET		Id_Tipo_Stato_Percorso = 3
				WHERE	Id_Percorso = @Id_Missione
						AND Sequenza_Percorso = @Sequenza_Percorso
			END	
			ELSE
			BEGIN
				-- L'ErrorCode non è nullo,quindi valorizzo l'xml della missione.
				WHILE	ISNULL(@Esistenza_Parametro,1) = 1
				BEGIN
					SELECT	@Esistenza_Parametro = Xml_Param.exist('//Error')
					FROM	Missioni
					WHERE	Id_Missione = @Id_Missione

					IF @Esistenza_Parametro = 1
					BEGIN
						UPDATE	Missioni
						SET		Xml_Param.modify	('delete //Error[1]')
						WHERE	Id_Missione = @Id_Missione
					END
					ELSE
					BEGIN
						UPDATE	Missioni
						SET		Xml_Param.modify('insert <Error>{sql:variable("@ErrorCode")}</Error> into (//Parametri)[1]')
						WHERE	Id_Missione = @Id_Missione
					END
				END

				SELECT	@ErrorCode_Desc = Descrizione
				FROM	Tipo_ErrorCode
				WHERE	Id_ErrorCode = @ErrorCode

				SET @Esistenza_Parametro = NULL

				WHILE	ISNULL(@Esistenza_Parametro,1) = 1
				BEGIN
					SELECT	@Esistenza_Parametro = Xml_Param.exist('//ErrorDesc')
					FROM	Missioni
					WHERE	Id_Missione = @Id_Missione

					IF @Esistenza_Parametro = 1
					BEGIN
						UPDATE	Missioni
						SET		Xml_Param.modify	('delete //ErrorDesc[1]')
						WHERE	Id_Missione = @Id_Missione
					END
					ELSE
					BEGIN
						UPDATE	Missioni
						SET		Xml_Param.modify('insert <ErrorDesc>{sql:variable("@ErrorCode_Desc")}</ErrorDesc> into (//Parametri)[1]')
						WHERE	Id_Missione = @Id_Missione
					END
				END				
			END
			
			FETCH NEXT FROM @Cursore INTO
			@Id_Missione
			,@Sequenza_Percorso
		END
			
		CLOSE @Cursore
		DEALLOCATE @Cursore 
		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION
		-- Return 1 se tutto è andato a buon fine;
		RETURN 0
	END TRY
	BEGIN CATCH
		-- Valorizzo l'errore con il nome della procedura corrente seguito dall'errore scatenato nel codice;
		SET @Errore = @Nome_StoredProcedure + ';' + ERROR_MESSAGE()
		-- Eseguo il rollback ed inserisco il log solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 
		BEGIN
			ROLLBACK TRANSACTION
			
			EXEC sp_Insert_Log	@Id_Processo = @Id_Processo
								,@Origine_Log = @Origine_Log
								,@Proprieta_Log = @Nome_StoredProcedure
								,@Id_Utente = @Id_Utente
								,@Id_Tipo_Log = 4
								,@Id_Tipo_Allerta = 0
								,@Messaggio = @Errore
								,@Errore = @Errore OUTPUT
		END
		-- Return 0 se la procedura è andata in errore;
		RETURN 1
	END CATCH
END



GO
