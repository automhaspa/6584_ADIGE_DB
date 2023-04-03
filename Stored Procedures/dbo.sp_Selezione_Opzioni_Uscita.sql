SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Selezione_Opzioni_Uscita]
	@Id_Opzione						INT,
	@Id_Evento						INT,
	@Id_Udc							INT,
	@Id_Messaggio					INT,
	@Id_Partizione_Destinazione		INT = NULL,
	-- Parametri Standard;
	@Id_Processo					VARCHAR(30),
	@Origine_Log					VARCHAR(25),
	@Id_Utente						VARCHAR(32),	
	@Errore							VARCHAR(500) OUTPUT
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT OFF;
	-- SET LOCK_TIMEOUT;

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(30);
	DECLARE @TranCount				INT;
	DECLARE @Return					INT;
	DECLARE @ErrLog					VARCHAR(500);

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure	= Object_Name(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount				= @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		DECLARE @START DATETIME = GETDATE()

		IF @Id_Utente IN ('awm', 'plccom')
			THROW 50001, 'ATTENZIONE, NON SEI AUTENTICATO!',1

		--SCARICA UDC IN AREA A TERRA
		IF @Id_Opzione = 1
		BEGIN
			--AGGIORNO POSIZIONE
			UPDATE	Udc_Posizione
			SET		Id_Partizione = 9103
			WHERE	Id_Udc = @Id_Udc

			DELETE	Eventi
			WHERE	Id_Tipo_Stato_Evento = 1
				AND Id_Tipo_Evento IN (3,4)
				AND Id_Partizione = 3203
		END
		ELSE IF (@Id_Opzione = 2) --CANCELLAZIONE UDC
		BEGIN
			DECLARE CursoreCancellazione CURSOR LOCAL FAST_FORWARD FOR
				SELECT	Id_Udc
				FROM	Udc_Posizione		UP
				JOIN	Messaggi_Ricevuti	MR
					ON	MR.ID_PARTIZIONE = UP.Id_Partizione
				WHERE	MR.ID_MESSAGGIO = @Id_Messaggio

			OPEN CursoreCancellazione
			FETCH NEXT FROM CursoreCancellazione INTO
				@ID_UDC

			WHILE @@FETCH_STATUS = 0
			BEGIN
				EXEC @Return = sp_Delete_EliminaUdc
						@Id_Udc			= @Id_Udc,
						@Id_Processo	= @Id_Processo,
						@Origine_Log	= @Origine_Log,
						@Id_Utente		= @Id_Utente,
						@Errore			= @Errore			OUTPUT

				FETCH NEXT FROM CursoreCancellazione INTO
					@ID_UDC
			END

			CLOSE CursoreCancellazione
			DEALLOCATE CursoreCancellazione
		END
		ELSE IF (@Id_Opzione = 3)
		BEGIN
			IF @Id_Partizione_Destinazione IS NULL
				THROW 50001, 'DEVI INDICARE A QUALE BAIA INVIARE L''UDC',1

			EXEC sp_Invia_Udc_A_Magazzino_Ingombranti
				@Id_Udc							= @Id_Udc,
				@Id_Partizione_Destinazione		= @Id_Partizione_Destinazione,
				@Id_Processo					= @Id_Processo,
				@Origine_Log					= @Origine_Log,
				@Id_Utente						= @Id_Utente,
				@Errore							= @Errore			OUTPUT
		END
		
		--CONSUNTIVAZIONE LISTA DI PRELIEVO PER RIGHE NON ANCORA COMPLETATE
		--SE SCARICANO A TERRA SENZA FARE PICKING INVIO I CONSUNTIVI A 0
		IF EXISTS(SELECT TOP 1 1 FROM Missioni_Picking_Dettaglio WHERE Id_Udc = @Id_Udc AND Id_Stato_Missione IN (2,3))
		BEGIN
			DECLARE @IdRigaLista		INT
			DECLARE @IdTestataLista		INT
			DECLARE @IdArticolo			INT
			DECLARE @Quantita			NUMERIC(10,2)
			DECLARE @Qta_Prelevata		NUMERIC(10,2)
			DECLARE @IdStatoMissione	INT
			DECLARE @FlVoid				NUMERIC(1,0)
			DECLARE @Qt_Consunt			NUMERIC(10,2)
			DECLARE @Id_UdcDettaglio	INT

			DECLARE CursoreRighePrelievoUdc CURSOR LOCAL FAST_FORWARD FOR
				SELECT	Id_Articolo,
						Id_Testata_Lista,
						Id_Riga_Lista,
						Quantita,
						Qta_Prelevata,
						Id_UdcDettaglio
				FROM	Missioni_Picking_Dettaglio
				WHERE	Id_Udc = @Id_Udc
					AND Id_Stato_Missione IN (2,3)

			OPEN CursoreRighePrelievoUdc
			FETCH NEXT FROM CursoreRighePrelievoUdc INTO
				@IdArticolo,
				@IdTestataLista,
				@IdRigaLista,
				@Quantita,
				@Qta_Prelevata,
				@Id_UdcDettaglio

			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @FlVoid = 0
					
				--Se mi elimina l'udc aggiorno le quantità prelevate CON LA QUANTITA MASSIMA PRESENTE SU UDC Aggiorno lo stato della missione picking dettaglio a Elaborato
				IF @Id_Opzione IN (1,3)
					SET @Qt_Consunt = @Quantita
				--SE ME LA SPOSTA A TERRA E' COME SE NON AVESSE PRELEVATO NULLA E INVIO IL CONSUNTIVO CON QUANTITA 0
				ELSE IF @Id_Opzione = 2
				BEGIN
					IF (@Qta_Prelevata = 0 OR @Qta_Prelevata < @Quantita)
						SET @FlVoid = 1

					SET @Qt_Consunt = @Qta_Prelevata
				END
				
				--Aggiorno lo stato della missione picking dettaglio a Elaborato
				UPDATE	Missioni_Picking_Dettaglio
				SET		Id_Stato_Missione = 4,
						Qta_Prelevata = @Qt_Consunt,
						DataOra_Evasione = GETDATE()
				WHERE	Id_Udc = @Id_Udc
					AND Id_Riga_Lista = @IdRigaLista
					AND Id_Testata_Lista = @IdTestataLista

				--CONSUNTIVO L3
				EXEC [dbo].[sp_Genera_Consuntivo_PrelievoLista]
							@Id_Udc				= @Id_Udc,
							@Id_Testata_Lista	= @IdTestataLista,
							@Id_Riga_Lista		= @IdRigaLista,
							@Qta_Prelevata		= @Qt_Consunt,
							@Fl_Void			= @FlVoid,
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Id_Utente			= @Id_Utente,
							@Errore				= @Errore			OUTPUT

				IF (ISNULL(@Errore, '') <> '')
					THROW 50100, @Errore, 1

				--Controllo fine Lista
				EXEC [dbo].[sp_Update_Stati_ListePrelievo]
							@Id_Testata_Lista	= @IdTestataLista,
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Id_Utente			= @Id_Utente,
							@Errore				= @Errore			OUTPUT

				FETCH NEXT FROM CursoreRighePrelievoUdc INTO
					@IdArticolo,
					@IdTestataLista,
					@IdRigaLista,
					@Quantita,
					@Qta_Prelevata,
					@Id_UdcDettaglio
			END
			
			CLOSE CursoreRighePrelievoUdc
			DEALLOCATE CursoreRighePrelievoUdc
		END
		
		--Elimino l'evento di selezione opzioni uscita
		DELETE	Eventi
		WHERE	Id_Evento = @Id_Evento

		DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Tempo impiegato: ', DATEDIFF(MILLISECOND,@START,GETDATE()),' MS')
		EXEC sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= @Nome_StoredProcedure,
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 4,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @MSG_LOG,
					@Errore				= @Errore OUTPUT;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION;
		-- Return 0 se tutto è andato a buon fine;
		RETURN 0;
	END TRY
	BEGIN CATCH
		-- Valorizzo l'errore con il nome della procedura corrente seguito dall'errore scatenato nel codice;
		SET @Errore = @Nome_StoredProcedure + ';' + ERROR_MESSAGE();
		-- Eseguo il rollback ed inserisco il log solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 
			BEGIN
				ROLLBACK TRANSACTION;

				EXEC sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= @Nome_StoredProcedure,
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 4,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @Errore,
					@Errore				= @Errore OUTPUT;
			
				-- Return 1 se la procedura è andata in errore;
				RETURN 1;
			END
		ELSE
			THROW;
	END CATCH;
END;
GO
