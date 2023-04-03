SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_Elabora_Messaggi]
-- Parametri Standard;
@Id_Processo		Varchar(30)	
,@Origine_Log		Varchar(25)	
,@Id_Utente			Varchar(32)		
,@Errore			Varchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	-- SET LOCK_TIMEOUT

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
	DECLARE @ErrLog Varchar(500)
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Cursore Cursor
		DECLARE @Id_Messaggio Int
		DECLARE @PROC VARCHAR(500)
		DECLARE @ID_TIPO_MESSAGGIO VARCHAR(5)

		-- Inserimento del codice;
		-- Questa procedura non deve essere sotto transazione.
		SET		@Cursore = CURSOR LOCAL FAST_FORWARD FOR
		SELECT	M.Id_Messaggio
				,LTRIM(RTRIM(ISNULL(PP.Procedura,PS.Procedura)))
				,M.Id_Tipo_Messaggio
		FROM	Messaggi_Ricevuti M 
				LEFT JOIN	Procedure_Personalizzate_Gestione_Messaggi PP 
							ON M.Id_Partizione = PP.Id_Partizione AND M.Id_Tipo_Messaggio = PP.Id_Tipo_Messaggio
				LEFT JOIN	Procedure_Gestione_Messaggi PS ON M.Id_Tipo_Messaggio = PS.Id_Tipo_Messaggio
		WHERE	M.Id_Tipo_Stato_Messaggio = 1
		ORDER BY M.Id_Messaggio ASC

		OPEN	@Cursore

		FETCH NEXT FROM @Cursore INTO 			
		@Id_Messaggio			
		,@PROC	
		,@ID_TIPO_MESSAGGIO 
		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- ELABORAZIONE DEL MESSAGGIO ALLA RICEZIONE
			DECLARE @ERRMESSAGE VARCHAR(MAX) = NULL, @MESSAGE_STATUS INT = NULL

			BEGIN TRY
				IF @PROC IS NULL
				BEGIN
					SET @ERRMESSAGE = 'NESSUNA PROCEDURA ASSOCIATA AL MESSAGGIO' +  @ID_TIPO_MESSAGGIO;
					THROW 50001, @ERRMESSAGE, 1
				END 	
				ELSE 
				BEGIN
					-- SALVO LA TRANSAZIONE CHE ELABORA IL MESSAGGIO
					SAVE TRANSACTION @PROC
					EXEC @PROC @Id_Messaggio,@Id_Processo,@Origine_Log,@Id_Utente,@ERRMESSAGE OUTPUT
					SET @MESSAGE_STATUS = 3
				END
			END TRY
			BEGIN CATCH
				-- SE LA TRANSAZIONE è ANCORA BUONA FACCIO IL ROLLBACK, ALTRIMENTI FACCIO IL ROLLBACK DI TUTTO
				IF XACT_STATE() = 1 ROLLBACK TRANSACTION @PROC
				ELSE THROW

				IF ERROR_NUMBER() NOT IN (1222,1205) 
				SET @MESSAGE_STATUS = 9		
				
				SET @Errore = ERROR_MESSAGE()

				EXEC sp_Insert_Log	@Id_Processo = @Id_Processo
									,@Origine_Log = @Origine_Log
									,@Proprieta_Log = @PROC
									,@Id_Utente = @Id_Utente
									,@Id_Tipo_Log = 4
									,@Id_Tipo_Allerta = 0
									,@Messaggio = @Errore
									,@Errore = @Errore OUTPUT
			END CATCH

			IF ISNULL(@MESSAGE_STATUS,0) <> 0
			EXEC sp_Update_Stato_Messaggi	@Id_Messaggio = @Id_Messaggio
											,@Id_Tipo_Stato_Messaggio = @MESSAGE_STATUS 
											,@Id_Tipo_Direzione_Messaggio = 'R'
											,@Id_Processo = @Id_Processo
											,@Origine_Log = @Origine_Log
											,@Id_Utente = @Id_Utente
											,@Errore = @Errore OUTPUT
			
			FETCH NEXT FROM @Cursore INTO 			
			@Id_Messaggio			
			,@PROC
			,@ID_TIPO_MESSAGGIO 
		END

		CLOSE @Cursore
		DEALLOCATE @Cursore
		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION
		-- Return 0 se tutto è andato a buon fine;
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
			-- Return 1 se la procedura è andata in errore;
			RETURN 1
		END ELSE THROW
	END CATCH
END


GO
