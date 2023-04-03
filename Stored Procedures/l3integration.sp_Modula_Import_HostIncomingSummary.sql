SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [l3integration].[sp_Modula_Import_HostIncomingSummary]
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
	DECLARE @Nome_StoredProcedure	VARCHAR(100);
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
		-- Dichiarazioni Variabili;
		DECLARE @LoadOrderId					nvarchar(20);
		DECLARE @LoadOrderType					nvarchar(100)		
		DECLARE @Quantity						numeric(10,2)
		DECLARE @PurchaseOrderIdLoadLineId		nvarchar(100)
		DECLARE @IdArticoloEntrato				int
		DECLARE @Username						varchar(32)
		--VARIABILI PE RORDINI ENTRATA MODULA
		DECLARE @IdMissione						int
		DECLARE @IdUdcDettaglioMov				int
		DECLARE @Id_Udc_Mov						int
		DECLARE @Qta_Da_Spostare_Missione_Udc	numeric(10,2)
		DECLARE @Id_Riga						int
		DECLARE @IdTestata						int
		DECLARE @IdRIgaDb						int
		--costante
		DECLARE @ID_UDC_MODULA					int = 702
		DECLARE @IdUdcDettaglioModula			int
		DECLARE @Qta_Caricata					numeric(10,2)
		DECLARE @Qta_Consuntivo					numeric(10,2)

		DECLARE	@Id_Testata_C					INT = 0
		DECLARE @LIT							VARCHAR(MAX)

		DECLARE @INVIA_STORNO BIT = 0

		--DEVO PORTARMI DIETRO ANCHE LA QUANTITY PERCHE' POSSO AVERE STESSO LOAD ORDER ID E LOAD LINE ID MA CON DIVERSE QUANTITA'
		DECLARE CursoreMerciEntrata CURSOR LOCAL FAST_FORWARD FOR
			SELECT	HIS.LOAD_ORDER_ID,
					HIS.LOAD_ORDER_TYPE,
					ISNULL(A.Id_Articolo, 0),
					HIS.PURCHASE_ORDER_ID_LOAD_LINE_ID,
					HIS.QUANTITY,
					ISNULL(HIS.USERNAME, 'NON DEFINITO')
			FROM	MODULA.HOST_IMPEXP.dbo.HOST_INCOMING_SUMMARY	HIS WITH(NOLOCK)
			JOIN	Articoli										A
			ON		A.Codice = HIS.ITEM_CODE

		--Scorro le testate
		OPEN CursoreMerciEntrata
		FETCH NEXT FROM CursoreMerciEntrata INTO
			@LoadOrderId,
			@LoadOrderType,
			@IdArticoloEntrato,
			@PurchaseOrderIdLoadLineId,
			@Quantity,
			@Username

		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
			SET @Id_Riga = NULL

			DECLARE @STL VARCHAR(max) = CONCAT( 'INIZIO ELABORAZIONE PER RECORD, LOAD ORDER ID: ', @LoadOrderId, ' TYPE: ', @LoadOrderType,' PURCHASE ORDER_LINE: ', @PurchaseOrderIdLoadLineId ,
												' ID ARTICOLO :', @IdArticoloEntrato ,' QUANTITY: ', @Quantity, '')
			EXEC sp_Insert_Log
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Proprieta_Log		= @Nome_StoredProcedure,
						@Id_Utente			= @Id_Utente,
						@Id_Tipo_Log		= 8,
						@Id_Tipo_Allerta	= 0,
						@Messaggio			= @STL,
						@Errore				= @Errore OUTPUT;

			SET @Qta_Consuntivo			= @Quantity
			SET @Id_Utente				= @Username
			SET @IdUdcDettaglioModula	= NULL

			SELECT	@IdUdcDettaglioModula = Id_UdcDettaglio
			FROM	Udc_Dettaglio
			WHERE	Id_Udc = @ID_UDC_MODULA
				AND Id_Articolo = @IdArticoloEntrato

			--CONTROLLO SE E' UNA LISTA DI ENTRATA MERCE INVIATA DA AUTOMHA
			IF EXISTS(SELECT TOP 1 1 FROM Custom.TestataOrdiniEntrata WHERE LOAD_ORDER_ID = @LoadOrderId AND LOAD_ORDER_TYPE = @LoadOrderType AND Stato <> 4)
			BEGIN
				SELECT	@Id_Riga = ISNULL(CAST(chunk AS INT), 0)
				FROM	SplitString(@PurchaseOrderIdLoadLineId, '_')
				WHERE	Passo = 2

				IF @Id_Riga IS NULL
					SELECT	@Id_Riga = ISNULL(CAST(chunk AS INT), 0)
					FROM	SplitString(@PurchaseOrderIdLoadLineId, '_')
					WHERE	Passo = 1

				IF @ID_RIGA IS NULL
					THROW 50009,'RIGA NON TROVATA',1

				SET @Id_Testata_C = NULL
				SET @LIT = 0
				SET @INVIA_STORNO = 0

				--CHIUSURA RIGA, INVIO IL CONSUNTIVO ED ELI
				IF @Qta_Consuntivo = 0
				BEGIN
					SELECT	@Id_Testata_C = ID
					FROM	Custom.TestataOrdiniEntrata
					WHERE	LOAD_ORDER_ID = @LoadOrderId
						AND LOAD_ORDER_TYPE = @LoadOrderType
						
					IF @Id_Testata_C IS NULL
						THROW 50009, 'TESTATA NON TROVATA',1

					IF EXISTS(SELECT TOP 1 1 FROM Custom.RigheOrdiniEntrata_Sospeso WHERE Id_Testata = @Id_Testata_C AND LOAD_LINE_ID = @Id_Riga)
					BEGIN
						SET @LIT = 'CANCELLATA RIGA SOSPENSIONE'
						DELETE Custom.RigheOrdiniEntrata_Sospeso WHERE Id_Testata = @Id_Testata_C AND LOAD_LINE_ID = @Id_Riga
					END
					EXEC [dbo].[sp_Genera_Consuntivo_EntrataLista]
								@Id_Udc				= @ID_UDC_MODULA,
								@Id_Testata_Ddt		= @Id_Testata_C,
								@Id_Riga_Ddt		= @Id_Riga,
								@Qta_Entrata		= @Qta_Consuntivo,
								@Fl_Quality_Check	= 0,
								@Fl_Void			= 1,
								@USERNAME			= @Username,
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Id_Utente			= @Id_Utente,
								@Errore				= @Errore				OUTPUT

					IF (ISNULL(@Errore, '') <> '')
						THROW 50006, @Errore, 1

					SET @LIT = CONCAT('CONSUNTIVAZIONE QUANTITA A ZERO ', @LoadOrderId, ' LINE: ', @Id_Riga ,' @quantity: ', @Qta_Consuntivo, ' - ', @LIT)
					EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 8,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @LIT,
							@Errore				= @Errore OUTPUT;
				END
				ELSE
                BEGIN
					SELECT	@Id_Testata_C = ID
					FROM	Custom.TestataOrdiniEntrata
					WHERE	LOAD_ORDER_ID = @LoadOrderId
						AND LOAD_ORDER_TYPE = @LoadOrderType
					
					IF EXISTS(SELECT TOP 1 1 FROM Custom.RigheOrdiniEntrata_Sospeso WHERE Id_Testata = @Id_Testata_C AND LOAD_LINE_ID = @Id_Riga)
					BEGIN
						UPDATE	Custom.RigheOrdiniEntrata_Sospeso
						SET		QTA_DA_CONSUNTIVARE -= @Qta_Consuntivo
						WHERE	Id_Testata = @Id_Testata_C
							AND LOAD_LINE_ID = @Id_Riga

						IF EXISTS(SELECT TOP 1 1 FROM Custom.RigheOrdiniEntrata_Sospeso WHERE Id_Testata = @Id_Testata_C AND LOAD_LINE_ID = @Id_Riga
							AND (QTA_DA_CONSUNTIVARE <= 0 OR QTA_DA_CONSUNTIVARE = QTA_DA_STORNARE))
						BEGIN
							DELETE	Custom.RigheOrdiniEntrata_Sospeso
							WHERE	Id_Testata = @Id_Testata_C
								AND LOAD_LINE_ID = @Id_Riga
								--AND QTA_DA_CONSUNTIVARE <= 0
								AND (QTA_DA_CONSUNTIVARE <= 0 OR QTA_DA_CONSUNTIVARE = QTA_DA_STORNARE)

							SET @INVIA_STORNO = 1
						END
					END
				END

				--UTILIZZATO QUANDO CI SONO PIU' UDC SPOSTAMENTO FACENTI RIFERIMENTO ALLA STESSA RIGA
				SELECT	@IdMissione = Id_Missione,
						@Id_Udc_Mov = ISNULL(ud.Id_Udc, 0),
						@IdUdcDettaglioMov = ISNULL(ud.Id_UdcDettaglio, 0),
						@Qta_Da_Spostare_Missione_Udc = ISNULL(ud.Quantita_Pezzi, 0),
						@IdTestata = toe.ID
				FROM	Missioni		M
				JOIN	Udc_Dettaglio	ud
				ON		m.Id_Udc = ud.Id_Udc
				JOIN	Custom.TestataOrdiniEntrata toe
				ON		toe.ID = ud.Id_Ddt_Reale
				WHERE	ud.Id_Articolo = @IdArticoloEntrato
					AND m.Id_Tipo_Missione = 'MTM'
					AND toe.LOAD_ORDER_ID = @LoadOrderId
					AND toe.LOAD_ORDER_TYPE = @LoadOrderType
					AND ud.Id_Riga_Ddt = @Id_Riga
				ORDER
					BY	ud.Quantita_Pezzi ASC

				IF (ISNULL(@Qta_Consuntivo, 0) > 0 AND ISNULL(@IdUdcDettaglioMov, 0) = 0 AND ISNULL(@Qta_Da_Spostare_Missione_Udc,0) = 0)
					THROW 50001, ' CONSUNTIVO NON CORRISPONDENTE A NESSUNA MISSIONE DI SPOSTAMENTO MERCE',1;
				
				IF (@IdUdcDettaglioMov <> 0 AND @Qta_Da_Spostare_Missione_Udc > 0  AND @Qta_Consuntivo > 0)
				BEGIN
					--PUO' ESSERE CHE LA QUANTITA DA SPOSTARE PER QUELLA MISSIONE SIA MAGGIORE RISPETTO ALLA QUANTITA CONSUNTIVATA 
					SET @Qta_Caricata = CASE
											WHEN (@Qta_Da_Spostare_Missione_Udc <= @Qta_Consuntivo) THEN @Qta_Da_Spostare_Missione_Udc
											WHEN (@Qta_Da_Spostare_Missione_Udc > @Qta_Consuntivo) THEN @Qta_Consuntivo
										END

					DECLARE @LInfo VARCHAR(max) = CONCAT( 'CARICO MODULA , LOAD ORDER ID: ', @LoadOrderId, ' LINE: ', @Id_Riga ,' Cursore_Udc_Spostamento: Id_Udc_Movimento: ', @Id_Udc_Mov, ' @Qta_Da_Spostare_Missione_Udc: ',
															@Qta_Da_Spostare_Missione_Udc, ' @Qta_Consuntivo: ', @Qta_Consuntivo , ' @Qta_Caricata calcolata: ', @Qta_Caricata  )
					EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 8,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @LInfo,
							@Errore				= @Errore OUTPUT;

					--PRELEVO DALL'UDC SPOSTAMENTO LA QUANTITA CARICATA
					EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
							@Id_Udc					= @Id_Udc_Mov,
							@Id_UdcDettaglio		= @IdUdcDettaglioMov, 
							@Id_Articolo			= @IdArticoloEntrato,
							@Qta_Pezzi_Input		= @Qta_Caricata,
							@Id_Causale_Movimento	= 2,
							@Id_Processo			= @Id_Processo,
							@Origine_Log			= @Origine_Log,
							@Id_Utente				= @Id_Utente,
							@Errore					= @Errore OUTPUT

					IF (ISNULL(@Errore, '') <> '')
						THROW 50001, @Errore, 1

					--CARICO IN MODULA LA QUANTITA DI SPOSTAMENTO DELL'UDC 
					EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
							@Id_Udc					= @ID_UDC_MODULA,
							@Id_UdcDettaglio		= @IdUdcDettaglioModula, 
							@Id_Articolo			= @IdArticoloEntrato,
							@Qta_Pezzi_Input		= @Qta_Caricata,
							@Id_Causale_Movimento	= 7,
							@Id_Ddt_Reale			= @IdTestata,
							@Id_Riga_Ddt			= @Id_Riga,
							@Flag_FlVoid			= 0,
							@FlagControlloQualita	= 0,
							@Id_Processo			= @Id_Processo,
							@Origine_Log			= @Origine_Log,
							@Id_Utente				= @Id_Utente,
							@Errore					= @Errore OUTPUT

					IF (ISNULL(@Errore, '') <> '')
						THROW 50001, @Errore, 1

					--prima di controllare lo stato riga aggiorno lo sotrico delle quantita entrate in modula
					INSERT INTO Custom.StoricoMerciEntrateModula
						(Id_Testata_Ddt_Reale, Id_Riga_Ddt_Reale, Id_Udc_Spostamento, Quantita_Movimentata)
					VALUES
						(@IdTestata, @Id_Riga, @Id_Udc_Mov, @Qta_Caricata)

					IF @INVIA_STORNO = 1
					BEGIN
						EXEC [dbo].[sp_Genera_Consuntivo_EntrataLista]
											@Id_Udc				= @ID_UDC_MODULA,
											@Id_Testata_Ddt		= @IdTestata,
											@Id_Riga_Ddt		= @Id_Riga,
											@Qta_Entrata		= 0,
											@Fl_Quality_Check	= 0,
											@Fl_Void			= 1,
											@USERNAME			= @Username,
											@Id_Processo		= @Id_Processo,
											@Origine_Log		= @Origine_Log,
											@Id_Utente			= @Id_Utente,
											@Errore				= @Errore				OUTPUT
						
						IF (ISNULL(@Errore, '') <> '')
							THROW 50006, @Errore, 1
							
						SET @LIT = CONCAT('CONSUNTIVAZIONE QUANTITA A ZERO ', @LoadOrderId, ' LINE: ', @Id_Riga ,' per chiusura forzata riga da AWM')
						EXEC sp_Insert_Log
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Proprieta_Log		= @Nome_StoredProcedure,
								@Id_Utente			= @Id_Utente,
								@Id_Tipo_Log		= 8,
								@Id_Tipo_Allerta	= 0,
								@Messaggio			= @LIT,
								@Errore				= @Errore OUTPUT;
					END

					--Chiudo la Missione
					IF (@Qta_Caricata = @Qta_Da_Spostare_Missione_Udc)
					BEGIN
						EXEC [dbo].[sp_Update_Stato_Missioni]
								@Id_Missione		= @IdMissione,
								@Id_Stato_Missione	= 'TOK',
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Id_Utente			= @Id_Utente,
								@Errore				= @Errore OUTPUT

						IF (@Errore IS NOT NULL)
							THROW 50001, @Errore, 1

						EXEC [dbo].[sp_Delete_EliminaUdc]
								@Id_Udc			= @Id_Udc_Mov,
								@Id_Processo	= @Id_Processo,
								@Origine_Log	= @Origine_Log,
								@Id_Utente		= @Id_Utente,
								@Errore			= @Errore		OUTPUT

						IF (@Errore IS NOT NULL)
							THROW 50001, @Errore, 1
					END

					EXEC [dbo].[sp_Update_Stati_OrdiniEntrata]
							@Id_Riga		= @Id_Riga,
							@Id_Testata		= @IdTestata,
							@FlagChiusura	= 0,
							@SpecModula		= 1,
							@Id_Processo	= @Id_Processo,
							@Origine_Log	= @Origine_Log,
							@Id_Utente		= @Id_Utente,
							@Errore			= @Errore		OUTPUT

					IF (ISNULL(@Errore, '') <> '')
						THROW 50001, @Errore, 1

					--PER OGNI CICLO DELLE UDC SPOSTAMENTO TOLGO LA QUANTITA CARICATA IN MODULA
					SET @Qta_Consuntivo = @Qta_Consuntivo - @Qta_Caricata
				END
				--Se la quantità consuntivo e' uguale 0 elimino le udc di spostamento ---> il consuntivo lo invio SOPRA
				ELSE IF (@IdUdcDettaglioMov <> 0 AND @Quantity = 0)
				BEGIN
					--TEMPORANEI PER DEBUGGING
					DECLARE @LI VARCHAR(max) = CONCAT( 'CHIUSURA MISSIONE INIZIALE LOAD ORDER ID: ', @LoadOrderId, ' LINE: ', @Id_Riga ,' Eliminazione Udc Fittizia di Movimento con ID: ', @Id_Udc_Mov, 
													' @Qta_Da_Spostare_Missione_Udc: ', @Qta_Da_Spostare_Missione_Udc, ' @Qta_Consuntivo: ', @Qta_Consuntivo , ' @Qta_Caricata calcolata: ', @Qta_Caricata)
					EXEC sp_Insert_Log
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Proprieta_Log		= @Nome_StoredProcedure,
						@Id_Utente			= @Id_Utente,
						@Id_Tipo_Log		= 8,
						@Id_Tipo_Allerta	= 0,
						@Messaggio			= @LI,
						@Errore				= @Errore OUTPUT;

					--SE HO UN ANNULLAMENTO CARICO, QUESTO PUO ESSERE DISTRIBUITO SU PIU' UDC
					--ALLORA LE ELIMINO TUTTE QUELLE CHE FANNO RIFERIMENTO ALLA STESSA RIGA
					DECLARE @Id_Missione_El		INT
					DECLARE @Id_Udc_El			INT

					DECLARE CursoreEliminazioneMissioni CURSOR LOCAL FAST_FORWARD FOR
						SELECT	Id_Missione,
								ud.Id_Udc
						FROM	Missioni					M
						JOIN	Udc_Dettaglio				UD
						ON		M.Id_Udc = UD.Id_Udc
						JOIN	Custom.TestataOrdiniEntrata TOE
						ON		toe.ID = ud.Id_Ddt_Reale
						WHERE	ud.Id_Articolo = @IdArticoloEntrato
							AND m.Id_Tipo_Missione = 'MTM'
							AND toe.LOAD_ORDER_ID = @LoadOrderId
							AND toe.LOAD_ORDER_TYPE = @LoadOrderType
							AND ud.Id_Riga_Ddt = @Id_Riga

					OPEN CursoreEliminazioneMissioni
					FETCH NEXT FROM CursoreEliminazioneMissioni INTO
						@Id_Missione_El,
						@Id_Udc_El

					WHILE @@FETCH_STATUS = 0
					BEGIN
						EXEC [dbo].[sp_Update_Stato_Missioni]
								@Id_Missione = @Id_Missione_El,
								@Id_Stato_Missione = 'TOK',
								@Id_Processo = @Id_Processo,
								@Origine_Log = @Origine_Log,
								@Id_Utente = @Id_Utente,
								@Errore = @Errore OUTPUT

						IF (@Errore IS NOT NULL)
							THROW 50001, @Errore, 1

						EXEC [dbo].[sp_Delete_EliminaUdc]
									@Id_Udc = @Id_Udc_El,
									@Id_Processo = @Id_Processo,
									@Origine_Log = @Origine_Log,
									@Id_Utente = @Id_Utente,
									@Errore = @Errore OUTPUT

						IF (@Errore IS NOT NULL)
							THROW 50001, @Errore, 1

						DECLARE @LIu VARCHAR(max) = CONCAT( 'CHIUSURA MISSIONE, CURSORE ELIMINAZIONE MISSIONI: Id_Udc: ',  @Id_Udc_El, ' Id_Missione: ', @Id_Missione_El
															, ' LOAD_ORDER_ID ', @LoadOrderId, ' LOAD_ORDER_TYPE ', @LoadOrderType)

						EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 8,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @LIu,
							@Errore				= @Errore OUTPUT;

						FETCH NEXT FROM CursoreEliminazioneMissioni INTO
							@Id_Missione_El,
							@Id_Udc_El
					END

					CLOSE CursoreEliminazioneMissioni
					DEALLOCATE CursoreEliminazioneMissioni
				END
				
				DECLARE @LogInfo VARCHAR(max)

				IF (@Qta_Consuntivo = 0)
				BEGIN
					SET XACT_ABORT ON
					DELETE	MODULA.HOST_IMPEXP.dbo.HOST_INCOMING_SUMMARY
					WHERE	LOAD_ORDER_ID = @LoadOrderId
						AND LOAD_ORDER_TYPE = @LoadOrderType
						AND PURCHASE_ORDER_ID_LOAD_LINE_ID = @PurchaseOrderIdLoadLineId
						AND QUANTITY = @Quantity
					SET XACT_ABORT OFF
					
					SET @LogInfo = CONCAT('PROCESSATO RECORD CON DELETE DA INCOMING SUM ID ARTICOLO: ', @IdArticoloEntrato, ' LOAD ORDER ID: ', @LoadOrderId, ' LINE: ', @Id_Riga , ' QUANTITY : ', @Quantity,
									' QUANTITA CARICATA IN MODULA: ' , @Qta_Caricata, '   QUANTITA CONSUNTIVO RIMANENENTE DA PROCESSARE: ', @Qta_Consuntivo, ' CODICE UDC SPOSTAMENTO : ', @Id_Udc_Mov )
				END
				ELSE
				BEGIN
					SET XACT_ABORT ON
					UPDATE	MODULA.HOST_IMPEXP.dbo.HOST_INCOMING_SUMMARY
					SET		Quantity = @Qta_Consuntivo
					WHERE	LOAD_ORDER_ID = @LoadOrderId
						AND LOAD_ORDER_TYPE = @LoadOrderType
						AND PURCHASE_ORDER_ID_LOAD_LINE_ID = @PurchaseOrderIdLoadLineId
						AND QUANTITY = @Quantity
					SET XACT_ABORT OFF
					
					SET @LogInfo = CONCAT('PROCESSATO RECORD CON UPDATE (IL VALORE QUANTITY DIVENTA: ''QUANTITA CONSUNTIVO RIMANENENTE'' SPECIFICATO NEL LOG) DA INCOMING SUM ID ARTICOLO: ', @IdArticoloEntrato, ' LOAD ORDER ID: ', @LoadOrderId, ' LINE: ', @Id_Riga , ' QUANTITY : ', @Quantity ,' QUANTITA CARICATA IN MODULA: ',
									@Qta_Caricata, '   QUANTITA CONSUNTIVO RIMANENENTE : ', @Qta_Consuntivo, ' CODICE UDC SPOSTAMENTO : ', @Id_Udc_Mov)

					EXEC sp_Insert_Log
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Proprieta_Log		= @Nome_StoredProcedure,
						@Id_Utente			= @Id_Utente,
						@Id_Tipo_Log		= 8,
						@Id_Tipo_Allerta	= 0,
						@Messaggio			= @LogInfo,
						@Errore				= @Errore OUTPUT
				END
			END
			ELSE
				THROW 50001, 'RECORD CHE NON CORRISPONDE A NESSUN ORDINE IN ENTRATA ATTIVO',1
			END TRY
			BEGIN CATCH
				DECLARE @Msg varchar(MAX) = CONCAT('ERRORE NEL PROCESSARE RECORD ID ARTICOLO: ', @IdArticoloEntrato, ' LOAD ORDER ID: ', @LoadOrderId, ' LOAD ORDER TYPE: ', @LoadOrderType  , ' QUANTITY :', @Quantity,
							' PurchaseOrderIdLoadLineId ' , @PurchaseOrderIdLoadLineId, ' MOTIVO: ', ERROR_MESSAGE())
				
				EXEC sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= @Nome_StoredProcedure,
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 4,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @Msg,
					@Errore				= @Errore OUTPUT
			END CATCH

			FETCH NEXT FROM CursoreMerciEntrata INTO
					@LoadOrderId,
					@LoadOrderType,
					@IdArticoloEntrato,
					@PurchaseOrderIdLoadLineId,
					@Quantity,
					@Username
		END

		CLOSE CursoreMerciEntrata
		DEALLOCATE CursoreMerciEntrata

		-- Fine del codice
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
