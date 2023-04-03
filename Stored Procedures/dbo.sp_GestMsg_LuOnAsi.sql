SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_GestMsg_LuOnAsi]
	@Id_Messaggio		Int,
	-- Parametri Standard;
	@Id_Processo		Varchar(30),
	@Origine_Log		Varchar(25),
	@Id_Utente			Varchar(32),
	@Errore				Varchar(500) OUTPUT
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
			DECLARE @ID_PARTIZIONE				INT
			DECLARE @ID_TIPO_MESSAGGIO			VARCHAR(5)
			DECLARE @ID_PARTIZIONE_DESTINAZIONE INT
			DECLARE @Id_Udc						INT
			DECLARE @ID_MISSIONE				INT
			DECLARE @XMLMESSAGE					XML
			DECLARE @LU_CONTAINER_TYPE			INT
			DECLARE @Tipo_Udc					VARCHAR(1)
			
			-- Inserimento del codice;
			SELECT	@ID_PARTIZIONE = ID_PARTIZIONE,
					@ID_TIPO_MESSAGGIO = ID_TIPO_MESSAGGIO,
					@XMLMESSAGE = MESSAGGIO
			FROM	Messaggi_Ricevuti
			WHERE	ID_MESSAGGIO = @Id_Messaggio
		
			--Se è presente un evento di tipo rejection attivo lo elimino
			DECLARE @IdEvRej	INT = 0
			
			DELETE	Eventi
			WHERE	Id_Partizione = 3101
				AND Id_Tipo_Evento = 1
				AND	Id_Tipo_Stato_Evento = 1

		--Recupero LU_CONTAINER_TYPE per identificare il tipo UDC 
		--Se = 1 allora Tipo A se = 2 allora Tipo B
		DECLARE @Id_Tipo_Udc INT
		SET @LU_CONTAINER_TYPE = @XMLMESSAGE.value('data(//LU_CONTAINER_TYPE)[1]', 'int')
		
		IF (@LU_CONTAINER_TYPE = 1)
			SET @Id_Tipo_Udc = 1
		ELSE IF (@LU_CONTAINER_TYPE = 2)
			SET @Id_Tipo_Udc = 4
		ELSE
			THROW 50005, 'CAMPO LU_CONTAINER_TYPE PUO'' ASSUMERE VALORE 1 O 2', 1

		--Genero l'Udc
		EXEC dbo.sp_Insert_Crea_Udc
						@Id_Tipo_Udc	= @Id_Tipo_Udc,
						@Id_Partizione	= @ID_PARTIZIONE,
						@Id_Udc			= @Id_Udc		OUTPUT,
						@Id_Processo	= @Id_Processo,
						@Origine_Log	= @Origine_Log,
						@Id_Utente		= @Id_Utente,
						@Errore			= @Errore		OUTPUT

		--Conoscendo il Container Type Recupero un Udc Casuale tra quelle anagrafata		
		DECLARE @Action XML = CONCAT(
										'<StoredProcedure ProcedureKey="selezionaTipoBolla">
											<ActionParameter>
											<Parameter>
												<ParameterName>Id_Udc</ParameterName>
												<ParameterValue>',@Id_Udc,'</ParameterValue>
											</Parameter>
											<Parameter>
												<ParameterName>Tipo_Udc</ParameterName>
												<ParameterValue>',@Tipo_Udc,'</ParameterValue>
											</Parameter>
											</ActionParameter>
										</StoredProcedure>'
									);
			
			EXEC [dbo].[sp_Insert_Eventi] 
								@Id_Tipo_Evento = 27 --riconoscimento Udc
								,@Id_Partizione = @Id_Partizione
								,@Id_Tipo_Messaggio = '11000'
								,@XmlMessage = @Action
								,@Id_Processo = @Id_Processo
								,@Origine_Log = @Origine_Log
								,@Id_Utente = @Id_Utente
								,@Errore = @Errore OUTPUT
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
				ROLLBACK 

				EXEC sp_Insert_Log	@Id_Processo = @Id_Processo
									,@Origine_Log = @Origine_Log
									,@Proprieta_Log = @Nome_StoredProcedure
									,@Id_Utente = @Id_Utente
									,@Id_Tipo_Log = 4
									,@Id_Tipo_Allerta = 0
									,@Messaggio = @Errore
									,@Errore = @Errore OUTPUT		
				-- Return 0 se la procedura è andata in errore;
				RETURN 1
			END
			ELSE THROW
		END CATCH
	END
GO
