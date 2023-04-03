SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_sendInside]
	@Id_Udc NUMERIC(18,0),
	@Id_Evento INT,
	-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(32),	
	@Errore			VARCHAR(500) OUTPUT
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
	SET @Nome_StoredProcedure	= OBJECT_NAME(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount				= @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Cursor CURSOR
		DECLARE	@Id_Udc_C INT
		DECLARE @Id_UdcDettaglio_C INT
		DECLARE @Id_Articolo_C INT
		DECLARE @Quantita_C NUMERIC(18,4)
		DECLARE	@Id_Gruppo_Lista_C INT
		DECLARE	@Id_Lista_C INT
		DECLARE	@Id_Dettaglio_C INT

		DECLARE @Id_Partizione_Destinazione INT = NULL

		-- Inserimento del codice;

		--Se l'evento non è nello stato 1 vado in errore.
		IF EXISTS( SELECT 1 FROM dbo.Eventi WHERE Id_Evento = @Id_Evento AND Id_Tipo_Stato_Evento <> 1)
			THROW 50001, 'SpEx_EventNotActive', 1

		-- Faccio un controllo tale per cui se ci sono righe nella Missioni_Dettaglio per l'Udc passata in ingresso che hanno ancora l'Id_Stato_Articolo <> 5 (diverso da prelevato)
		-- allora lancio un eccezione
		IF NOT EXISTS(SELECT 1 FROM dbo.Missioni_Dettaglio WHERE Id_Udc = @Id_Udc AND Id_Stato_Articolo <> 5)
			BEGIN
				--CHIUDO L'EVENTO IN INGRESSO
				UPDATE dbo.Eventi SET Id_Tipo_Stato_Evento = 3 WHERE Id_Evento = @Id_Evento

				--SETTO UN CURSORE CHE PRENDE TUTTI I DATI NECESSARI PER CHIAMARE LA STORED PROCEDURE DI AGGIORNAMENTO CONTENUTO UDC
				SET @Cursor = CURSOR LOCAL FAST_FORWARD FOR
					SELECT		Id_Udc,
								Id_UdcDettaglio,
								Id_Articolo,
								Quantita,
								Id_Gruppo_Lista,
								Id_Lista,
								Id_Dettaglio
					FROM		dbo.Missioni_Dettaglio
					WHERE		Id_Udc = @Id_Udc

				OPEN @Cursor
				FETCH NEXT FROM @Cursor INTO
					 @Id_Udc_C
					,@Id_UdcDettaglio_C
					,@Id_Articolo_C
					,@Quantita_C
					,@Id_Gruppo_Lista_C
					,@Id_Lista_C
					,@Id_Dettaglio_C

				WHILE @@FETCH_STATUS = 0
					BEGIN	
						-- inizio codice cursore
						
						--AGGIORNO L'UDC_DETTAGLIO TOGLIENDO LA QUANTITA' PRELEVATA (CHIAMANDO L'APPOSITA STORED PROCEDURE)
						EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc	@Id_Udc = @Id_Udc_C,
																	@Id_UdcDettaglio = @Id_UdcDettaglio_C, 
																	@Id_Articolo = @Id_Articolo_C,
																	@Qta_Pezzi_Input = @Quantita_C,
																	@Id_Causale_Movimento = 1,
																	@Id_Gruppo_Lista = @Id_Gruppo_Lista_C,
																	@Id_Lista = @Id_Lista_C,
																	@Id_Dettaglio = @Id_Dettaglio_C,
																	@Id_Processo = @Id_Processo,
																	@Origine_Log = @Origine_Log,
																	@Id_Utente = @Id_Utente,
																	@Errore = @Errore OUTPUT
						-- fine codice cursore
						FETCH NEXT FROM @Cursor INTO
							 @Id_Udc_C
							,@Id_UdcDettaglio_C
							,@Id_Articolo_C
							,@Quantita_C
							,@Id_Gruppo_Lista_C
							,@Id_Lista_C
							,@Id_Dettaglio_C
					END
				
				CLOSE @Cursor
				DEALLOCATE @Cursor


				--PRENDO LA DESTINAZIONE DALLE PROCEDURE_PERSONALIZZATE_GESTIONE_MESSAGGI E CREO LA MISSIONE
				SELECT		@Id_Partizione_Destinazione = Id_Partizione_OK
				FROM		dbo.Procedure_Personalizzate_Gestione_Messaggi PPGM
				INNER JOIN	dbo.Eventi E ON E.Id_Partizione = PPGM.Id_Partizione
				WHERE		E.Id_Evento = @Id_Evento
				AND			PPGM.Id_Tipo_Messaggio = 11000

				--SE LA DESTINAZIONE NON E' NULLA CREO LA MISSIONE DALLA BAIA AL CONTROLLO SAGOMA
				IF(@Id_Partizione_Destinazione IS NOT NULL)
					BEGIN

						EXEC dbo.sp_Insert_CreaMissioni		@Id_Udc = @Id_Udc,                       
															@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,                  
															@Id_Tipo_Missione = 'ING',             
															@Xml_Param = '',					
															@Id_Processo = @Id_Processo,                  
															@Origine_Log = @Origine_Log,                  
															@Id_Utente = @Id_Utente,                    
															@Errore = @Errore OUTPUT
						
					END
				ELSE --SE INVECE E' NULLA ALLORA LANCIO UN ECCEZIONE
					THROW 50001, 'SpEx_DestinationNotFound', 1
			END
		ELSE
			THROW 50001, 'SpEx_PickingNotComplete', 1



		-- Fine del codice;

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
