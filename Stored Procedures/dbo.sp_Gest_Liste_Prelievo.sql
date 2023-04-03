SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

	CREATE PROCEDURE [dbo].[sp_Gest_Liste_Prelievo]
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
		SET @Nome_StoredProcedure	= Object_Name(@@ProcId);
		-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
		SET @TranCount				= @@TRANCOUNT;

		-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
		IF @TranCount = 0 BEGIN TRANSACTION;

		BEGIN TRY
			DECLARE @START DATETIME = GETDATE()
		
			-- Dichiarazioni Variabili;
			DECLARE @ErroreCreaMissione			VARCHAR(MAX)
			DECLARE @Id_Udc_T					INT
			DECLARE @IdPartizioneSorgente		INT
			DECLARE	@NUdcDettaglio				INT
			DECLARE @DettaglioCompleteUdc		INT
			DECLARE @Id_Tipo_Missione			VARCHAR(3)
			DECLARE @IdTipoUdc					INT
			DECLARE @PostiLiberiBufferA			INT
			DECLARE @PostiLiberiBufferB			INT
			DECLARE @IdPartizioneDestCalc		INT
			DECLARE @Id_Partizione_Destinazione	INT
			DECLARE @KitId						INT
			DECLARE @IdTestataLista				INT
			DECLARE @FSC						BIT

			--Raggruppo l'udc 
			DECLARE CursorTasks CURSOR LOCAL FAST_FORWARD FOR
				SELECT	MD.Id_Udc,
						UT.Id_Tipo_Udc,
						UP.Id_Partizione		Id_Partizione_Sorgente,
						MD.Id_Partizione_Destinazione,
						MD.Kit_Id,
						MD.Id_Testata_Lista,
						MD.Flag_SvuotaComplet
				FROM	dbo.Missioni_Picking_Dettaglio	MD
				JOIN	Udc_Posizione					UP	ON up.Id_Udc = MD.Id_Udc
					AND ISNULL(MD.FL_MANCANTI,0) = 0
				JOIN	Udc_Testata						UT	ON ut.Id_Udc = MD.Id_Udc
				JOIN	Custom.TestataListePrelievo		TLP ON MD.Id_Testata_Lista = tlp.ID
				JOIN	Partizioni						P	ON up.Id_Partizione = p.ID_PARTIZIONE
				LEFT
				JOIN	Custom.OrdineKittingBaia		okb ON (okb.Id_Testata_Lista = MD.Id_Testata_Lista AND okb.Kit_Id = MD.Kit_Id)
				LEFT
				JOIN	Custom.OrdineKittingUdc			oku ON (oku.Id_Testata_Lista = MD.Id_Testata_Lista AND oku.Kit_Id = MD.Kit_Id)
				LEFT
				JOIN	Missioni						M
				ON		M.Id_Udc = MD.Id_Udc
				WHERE	M.ID_MISSIONE IS NULL	--UDC NON IN MISSIONE
					AND	tlp.Stato <> 5			--TESTATA IN STATO DI EVASIONE IN CORSO
					AND mD.Id_Stato_Missione = 1
					AND p.ID_TIPO_PARTIZIONE = 'MA'
					AND ut.Id_Udc <> 702
					--AND	ut.Id_Udc IN (83044,85156,86391,84666,96343,72861,96779,95423,85855,81858,78336,86269,84661,94400) 
					--Controlli per le uscite kitting
					AND	(
							(MD.Kit_Id = 0 AND okb.Id_Testata_Lista IS NULL)
								OR
							(MD.Kit_Id > 0 AND ISNULL(oku.Stato_Udc_Kit,0) = 1)
						)
				GROUP
					BY	Md.Id_Udc, MD.Id_Partizione_Destinazione, ut.Id_Tipo_Udc, up.Id_Partizione, MD.Kit_Id, MD.Id_Testata_Lista, p.ID_PARTIZIONE, MD.Flag_SvuotaComplet
				ORDER
					BY	Flag_SvuotaComplet, MD.Id_Testata_Lista

			OPEN CursorTasks
			FETCH NEXT FROM CursorTasks INTO
					@Id_Udc_T,
					@IdTipoUdc,
					@IdPartizioneSorgente,
					@Id_Partizione_Destinazione,
					@KitId,
					@IdTestataLista,
					@FSC
				
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @DettaglioCompleteUdc = 0
				SET @PostiLiberiBufferA = 0
				SET @PostiLiberiBufferB = 0
				SET @IdPartizioneDestCalc = 0

				--Setto l'Id tipo missione --Se di tipo A
				IF @IdTipoUdc IN ('1','2','3')
				BEGIN
					--Recuper le udc dettaglio in lista che saranno prelevate completamente dall'Udc
					SELECT	@DettaglioCompleteUdc = COUNT(1)
					FROM	Missioni_Picking_Dettaglio
					WHERE	Id_Udc = @Id_Udc_T
						AND Flag_SvuotaComplet = 1
						AND Id_Testata_Lista = @IdTestataLista

					--Recuper il numero di Udc dettaglio sull'Udc in questione
					SELECT	@NUdcDettaglio = COUNT(1)
					FROM	Udc_Dettaglio
					WHERE	Id_Udc = @Id_Udc_T

					--Se il numero di Dettaglio corrisponde al numero Di Dettaglio che devono essere prelevate completamente													
					IF	@DettaglioCompleteUdc > 0
							AND
						@DettaglioCompleteUdc = @NUdcDettaglio
					BEGIN
						--Se l'udc è da scaricare completamente avvio un altro tipo di missione per lo scarico da baia
						SET @IdPartizioneDestCalc = CASE
														WHEN @Id_Partizione_Destinazione = 3404 THEN 3403
														WHEN @Id_Partizione_Destinazione = 3604 THEN 3603
													END

						SET @Id_Tipo_Missione = CASE
													WHEN @KitId = 0 THEN 'OUC'
													ELSE 'OUK'
												END
					END
					--Altrimenti avvio una normale missione di picking
					ELSE
					BEGIN
						SET @IdPartizioneDestCalc = @Id_Partizione_Destinazione

						SET @Id_Tipo_Missione = CASE
													WHEN @KitId = 0 THEN 'OUL'
													ELSE 'OUK'
												END
					END
				
					SELECT	@PostiLiberiBufferA = PostiLiberiBuffer
					FROM	Custom.vBufferMissioni	vb
					WHERE	vb.Id_Sottoarea =	(
													SELECT	sa.ID_SOTTOAREA
													FROM	SottoAree		sa
													JOIN	Componenti		c on sa.ID_SOTTOAREA = c.ID_SOTTOAREA
													JOIN	SottoComponenti sc ON sc.ID_COMPONENTE = c.ID_COMPONENTE
													JOIN	Partizioni		p ON p.ID_SOTTOCOMPONENTE = sc.ID_SOTTOCOMPONENTE
													WHERE	ID_PARTIZIONE = @Id_Partizione_Destinazione
												)
						AND	vb.Tipo_Missione =	CASE
													WHEN @Id_Tipo_Missione IN ('OUK','OUC') THEN 'OUL'
													ELSE @Id_Tipo_Missione
												END

					IF @PostiLiberiBufferA > 0
					BEGIN
						BEGIN TRY
							DECLARE @ErrorMission VARCHAR(MAX);
							SET		@ErrorMission = ''

							EXEC dbo.sp_Insert_CreaMissioni
										@Id_Udc						= @Id_Udc_T,
										@Id_Partizione_Destinazione = @IdPartizioneDestCalc,
										@Id_Tipo_Missione			= @Id_Tipo_Missione,
										@Xml_Param					= '',
										@Id_Processo				= @Id_Processo,
										@Origine_Log				= @Origine_Log,
										@Id_Utente					= @Id_Utente,
										@Errore						= @ErrorMission	OUTPUT

								--Controllo se non ho errori in fase di creazione Missione  (Tipo percorso non trovato se la partizione e' in lock) altrimenti lascio in stato 1
							IF ISNULL(@ErrorMission,'')=''
								UPDATE	Missioni_Picking_Dettaglio
								SET		Id_Stato_Missione = 2
								WHERE	Id_Udc = @Id_Udc_T
									AND Id_Partizione_Destinazione = @IdPartizioneDestCalc
									AND Id_Testata_Lista = @IdTestataLista
									AND Id_Stato_Missione = 1
						END TRY
						BEGIN CATCH
							SET @ErroreCreaMissione = CONCAT('ERRORE CREAZIONE MISSIONE UDC TIPO A: ', @Errore, ' Id_Udc : ' , @Id_Udc_T, ' Verso:', @IdPartizioneDestCalc, '  ', ERROR_MEssage())

							EXEC sp_Insert_Log
									@Id_Processo		= @Id_Processo,
									@Origine_Log		= @Origine_Log,
									@Proprieta_Log		= @Nome_StoredProcedure,
									@Id_Utente			= @Id_Utente,
									@Id_Tipo_Log		= 4,
									@Id_Tipo_Allerta	= 0,
									@Messaggio			= @ErroreCreaMissione,
									@Errore				= @Errore OUTPUT;
						END CATCH
					END
				END
				--Se l'udc è  di tipo  B
				ELSE IF (@IdTipoUdc IN ('4','5','6'))
				BEGIN
					SELECT	@PostiLiberiBufferB = PostiLiberiBuffer
					FROM	Custom.vBufferMissioni
					WHERE	Id_Sottoarea = 32

					--Contollo che ci sia posto sulle rulliere in sottoarea 32
					IF (@PostiLiberiBufferB > 0)
					BEGIN
						--Recuper le udc dettaglio in lista che saranno prelevate completamente dall'Udc
						SELECT	@DettaglioCompleteUdc = COUNT(1)
						FROM	Missioni_Picking_Dettaglio mpd
						WHERE	mpd.Id_Udc = @Id_Udc_T
							AND	mpd.Flag_SvuotaComplet = 1
							AND mpd.Id_Testata_Lista = @IdTestataLista

						--Recuper il numero di Udc dettaglio sull'Udc in questione
						SELECT	@NUdcDettaglio = COUNT(1)
						FROM	Udc_Dettaglio
						WHERE	Id_Udc = @Id_Udc_T

						IF	@DettaglioCompleteUdc > 0
								AND
							@DettaglioCompleteUdc = @NUdcDettaglio
							SET @Id_Tipo_Missione =	CASE
														WHEN @KitId = 0 THEN 'OUC'
														ELSE 'OUK'
													END

						--Altrimenti avvio una normale missione di picking
						ELSE
							SET @Id_Tipo_Missione =	CASE
														WHEN @KitId = 0 THEN 'OUL'
														ELSE 'OUK'
													END

						--La mando in baia di outbound già definita in fase di avvio
						SET @IdPartizioneDestCalc = @Id_Partizione_Destinazione

						BEGIN TRY
							EXEC dbo.sp_Insert_CreaMissioni
										@Id_Udc						= @Id_Udc_T,
										@Id_Partizione_Destinazione = @IdPartizioneDestCalc,
										@Id_Gruppo_Lista			= NULL,
										@Id_Tipo_Missione			= @Id_Tipo_Missione,
										@Xml_Param					= '',
										@Id_Processo				= @Id_Processo,
										@Origine_Log				= @Origine_Log,
										@Id_Utente					= @Id_Utente,
										@Errore						= @Errore				OUTPUT

							--Controllo se non ho errori in fase di creazione Missione  (Tipo percorso non trovato se la partizione e' in lock) altrimenti lascio in stato 1
							IF ISNULL(@Errore,'') = ''
								UPDATE	Missioni_Picking_Dettaglio
								SET		Id_Stato_Missione = 2
								WHERE	Id_Udc = @Id_Udc_T
									AND Id_Partizione_Destinazione = @IdPartizioneDestCalc
									AND Id_Testata_Lista = @IdTestataLista
									AND Id_Stato_Missione = 1
						END TRY
						BEGIN CATCH
							SET @ErroreCreaMissione = CONCAT('ERRORE CREAZIONE MISSIONE UDC TIPO B: ', @Errore, ' Id_Udc : ' , @Id_Udc_T , '  ', ERROR_MEssage())

							--Loggo l'impossibilità di avviare la missione
							EXEC sp_Insert_Log
									@Id_Processo		= @Id_Processo,
									@Origine_Log		= @Origine_Log,
									@Proprieta_Log		= @Nome_StoredProcedure,
									@Id_Utente			= @Id_Utente,
									@Id_Tipo_Log		= 4,
									@Id_Tipo_Allerta	= 0,
									@Messaggio			= @ErroreCreaMissione,
									@Errore				= @Errore OUTPUT;
						END CATCH
					END
				END

				FETCH NEXT FROM CursorTasks INTO
						@Id_Udc_T,
						@IdTipoUdc,
						@IdPartizioneSorgente,
						@Id_Partizione_Destinazione,
						@KitId,
						@IdTestataLista,
						@FSC
			END

			CLOSE CursorTasks
			DEALLOCATE CursorTasks

			DECLARE @TEMPO INT = DATEDIFF(MILLISECOND,@START,GETDATE())

			IF @TEMPO > 500
			BEGIN
				DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Creazione Missioni Uscita - TEMPO IMPIEGATO ',@TEMPO)
				EXEC dbo.sp_Insert_Log
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Proprieta_Log		= 'Tempistiche',
						@Id_Utente			= @Id_Utente,
						@Id_Tipo_Log		= 16,
						@Id_Tipo_Allerta	= 0,
						@Messaggio			= @MSG_LOG,
						@Errore				= @Errore OUTPUT;
			END

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
