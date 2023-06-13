SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [l3integration].[sp_Manage_HostQualityChanges]
	-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(32),
	@Errore			VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT OFF;

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(100)
	DECLARE @TranCount				INT
	DECLARE @Return					INT
	DECLARE @ErrLog					VARCHAR(500)

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = OBJECT_NAME(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		DECLARE @START				DATETIME = GETDATE()
		DECLARE @Qta_Stock			INT
		DECLARE @XMLPARAMETER		VARCHAR(MAX)

		DECLARE @Id_Udc_Dettaglio	INT
		DECLARE @ID_UDC				INT
		DECLARE @Qta_Pezzi			INT
		DECLARE @WBS_RIFERIMENTO	VARCHAR(40)
		DECLARE @Id_Partizione		INT

		-- Dichiarazioni Variabili;
		DECLARE @ID					INT
		DECLARE @CONTROL_LOT_C		VARCHAR(40)
		DECLARE @Id_Articolo_C		INT
		DECLARE @QUANTITY_C			INT
		DECLARE @STAT_QUAL_NEW_C	VARCHAR(4)
		DECLARE @STAT_QUAL_OLD_C	VARCHAR(4)

		--Carico gli articoli da elaborare
		DECLARE Cursore_QualChanges CURSOR LOCAL FAST_FORWARD FOR
			SELECT	ID,
					CONTROL_LOT,
					Id_Articolo,
					QUANTITY,
					STAT_QUAL_OLD,
					STAT_QUAL_NEW
			FROM	l3integration.Quality_Changes
			WHERE	Id_Tipo_Stato_Messaggio = 1
			ORDER
				BY	TimeStamp

		--Elaboro ogni Testata ordine 
		OPEN Cursore_QualChanges
		FETCH NEXT FROM Cursore_QualChanges INTO
			@ID,
			@CONTROL_LOT_C,
			@Id_Articolo_C,
			@QUANTITY_C,
			@STAT_QUAL_OLD_C,
			@STAT_QUAL_NEW_C

		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				SET @Qta_Stock = 0
				SET @XMLPARAMETER		= CONCAT('	<Parametri>
														<Control_Lot_Filtro>|',@CONTROL_LOT_C,'</Control_Lot_Filtro>
														<Id_Articolo>',@Id_Articolo_C,'</Id_Articolo>
													</Parametri>')

				--FACCIO QUELLO CHE FA LA PROCEDURA NORMALE CON IL LIMITE DELLA QUANTITA' RICHIESTA
				IF @STAT_QUAL_NEW_C = 'BLOC'
				BEGIN
					--VERIFICO PRIMA DI TUTTO SE LA QUANTITA' RICHIESTA E' UGUALE A QUELLA A STOCK
					SELECT	@Qta_Stock = SUM(CQ.Quantita)
					FROM	Custom.ControlloQualita	CQ
					JOIN	dbo.Udc_Dettaglio			UD
					ON		UD.Id_UdcDettaglio = CQ.Id_UdcDettaglio
					WHERE	UD.Id_Articolo = @Id_Articolo_C
						AND CQ.Quantita > 0
						AND ISNULL(@Control_Lot_C,CQ.Control_Lot) = CQ.Control_Lot
						AND ISNULL(CQ.Doppio_Step_QM,0) = 1

					IF ISNULL(@Qta_Stock,0) <> @QUANTITY_C
						EXEC dbo.sp_Insert_Eventi
							@Id_Tipo_Evento		= 51,
							@Id_Partizione		= 3701,
						    @Id_Tipo_Messaggio	= '1100',
						    @XmlMessage			= @XMLPARAMETER,
						    @Id_Processo		= @Id_Processo,
						    @Origine_Log		= @Origine_Log,
						    @Id_Utente			= @Id_Utente,
						    @Errore				= @Errore		OUTPUT
					ELSE
					BEGIN
						DECLARE Bloc_UDC_C CURSOR LOCAL FAST_FORWARD FOR
							SELECT	UD.Id_UdcDettaglio,
									UD.Quantita_Pezzi
							FROM	Custom.ControlloQualita		CQ
							JOIN	dbo.Udc_Dettaglio			UD
							ON		UD.Id_UdcDettaglio = CQ.Id_UdcDettaglio
							WHERE	UD.Id_Articolo = @Id_Articolo_C
								AND CQ.Quantita > 0
								AND ISNULL(@Control_Lot_C,CQ.Control_Lot) = CQ.Control_Lot
								AND ISNULL(CQ.Doppio_Step_QM,0) = 1

						OPEN Bloc_UDC_C
						FETCH NEXT FROM Bloc_UDC_C INTO
							@ID_UDC_DETTAGLIO,
							@Qta_Pezzi

						WHILE @@FETCH_STATUS = 0
						BEGIN
							IF EXISTS (SELECT TOP(1) 1 FROM Custom.ControlloQualita WHERE Id_UdcDettaglio = @Id_Udc_Dettaglio AND Quantita <= @QUANTITY_C)
								DELETE	Custom.ControlloQualita
								WHERE	Id_UdcDettaglio = @Id_Udc_Dettaglio
									AND ISNULL(@CONTROL_LOT_C,'') = ISNULL(CONTROL_LOT,'')
									AND ISNULL(Doppio_Step_QM,0) = 1
							ELSE
								UPDATE	Custom.ControlloQualita
								SET		Quantita = Quantita - @QUANTITY_C
								WHERE	Id_UdcDettaglio = @Id_Udc_Dettaglio
									AND ISNULL(@CONTROL_LOT_C,'') = ISNULL(CONTROL_LOT,'')
									AND ISNULL(Doppio_Step_QM,0) = 1

							IF NOT EXISTS (SELECT TOP(1) 1 FROM Custom.NonConformita WHERE Id_UdcDettaglio = @Id_Udc_Dettaglio)
								INSERT INTO Custom.NonConformita
								VALUES (@Id_Udc_Dettaglio, @QUANTITY_C,'2 STEP QM',ISNULL(@CONTROL_LOT_C,''))
							ELSE
								UPDATE	Custom.NonConformita
								SET		Quantita = Quantita + @QUANTITY_C
								WHERE	Id_UdcDettaglio = @Id_Udc_Dettaglio
									AND ISNULL(@CONTROL_LOT_C,'') = ISNULL(CONTROL_LOT,'')

							FETCH NEXT FROM Bloc_UDC_C INTO
								@ID_UDC_DETTAGLIO,
								@Qta_Pezzi
						END
					END

					CLOSE Bloc_UDC_C
					DEALLOCATE Bloc_UDC_C
				END

				--SE DEVO LIBERARE QUALCOSA INVECE DEVO RIMUOVERE DAL CONTROLLO QUALITA' QUELLO CHE C'ERA
				IF @STAT_QUAL_NEW_C = 'DISP'
				BEGIN
					SELECT	@Qta_Stock = SUM(CQ.Quantita)
					FROM	Custom.ControlloQualita		CQ
					JOIN	dbo.Udc_Dettaglio			UD
					ON		UD.Id_UdcDettaglio = CQ.Id_UdcDettaglio
					WHERE	UD.Id_Articolo = @Id_Articolo_C
						AND CQ.Quantita > 0
						AND ISNULL(@Control_Lot_C,CQ.Control_Lot) = CQ.Control_Lot
						AND ISNULL(CQ.Doppio_Step_QM,0) = 1

					IF ISNULL(@Qta_Stock,0) <> @QUANTITY_C
						EXEC dbo.sp_Insert_Eventi
							@Id_Tipo_Evento		= 52,
							@Id_Partizione		= 3701,
						    @Id_Tipo_Messaggio	= '1100',
						    @XmlMessage			= @XMLPARAMETER,
						    @Id_Processo		= @Id_Processo,
						    @Origine_Log		= @Origine_Log,
						    @Id_Utente			= @Id_Utente,
						    @Errore				= @Errore		OUTPUT
					ELSE
					BEGIN
						DECLARE Disp_UDC_C CURSOR LOCAL FAST_FORWARD FOR
							SELECT	UD.ID_UDC,
									UD.Id_UdcDettaglio,
									UD.Quantita_Pezzi,
									UD.WBS_Riferimento,
									UP.Id_Partizione
							FROM	Custom.ControlloQualita		CQ
							JOIN	dbo.Udc_Dettaglio			UD
							ON		UD.Id_UdcDettaglio = CQ.Id_UdcDettaglio
							JOIN	dbo.Udc_Testata				UT
							ON		UT.Id_Udc = UD.Id_Udc
							JOIN	dbo.Udc_Posizione			UP
							ON		UP.Id_Udc = UT.Id_Udc
							WHERE	UD.Id_Articolo = @Id_Articolo_C
								AND CQ.Quantita > 0
								AND ISNULL(@CONTROL_LOT_C,'') = ISNULL(CQ.CONTROL_LOT,'')
								AND ISNULL(CQ.Doppio_Step_QM,0) = 1
							
						OPEN Disp_UDC_C
						FETCH NEXT FROM Disp_UDC_C INTO
							@ID_UDC,
							@ID_UDC_DETTAGLIO,
							@Qta_Pezzi,
							@WBS_RIFERIMENTO,
							@Id_Partizione

						WHILE @@FETCH_STATUS = 0
						BEGIN
							IF EXISTS	(
											SELECT	TOP(1) 1
											FROM	Custom.ControlloQualita
											WHERE	Id_UdcDettaglio = @Id_Udc_Dettaglio
												AND ISNULL(@CONTROL_LOT_C,'') = ISNULL(CONTROL_LOT,'')
												AND Quantita <= @QUANTITY_C
												AND ISNULL(Doppio_Step_QM,0) = 1
										)
								DELETE	Custom.ControlloQualita
								WHERE	Id_UdcDettaglio = @Id_Udc_Dettaglio
									AND ISNULL(@CONTROL_LOT_C,'') = ISNULL(CONTROL_LOT,'')
									AND ISNULL(Doppio_Step_QM,0) = 1
							ELSE
								UPDATE	Custom.ControlloQualita
								SET		Quantita = Quantita - @QUANTITY_C
								WHERE	Id_UdcDettaglio = @Id_Udc_Dettaglio
									AND ISNULL(@CONTROL_LOT_C,'') = ISNULL(CONTROL_LOT,'')
									AND ISNULL(Doppio_Step_QM,0) = 1
								
							IF	(
									@Id_Partizione = 3701 ---o se l'udc e' ingombrante
										OR
									EXISTS	(
												SELECT	TOP 1 1
												FROM	Udc_Testata
												WHERE	Id_Udc = @ID_UDC
													AND Id_Tipo_Udc IN ('I','M')
											)
								)
									AND
								EXISTS	(
											SELECT	TOP(1) 1
											FROM	Custom.AnagraficaMancanti
											WHERE	Id_Articolo = @Id_Articolo_C
												AND Qta_Mancante > 0
												AND ISNULL(WBS_Riferimento,'') = ISNULL(@WBS_Riferimento,'')
										)
							BEGIN
								DECLARE @XmlParam xml = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc><Id_Articolo>',@Id_Articolo_C,'</Id_Articolo>
																<Missione_Modula>',0,'</Missione_Modula></Parametri>')

								EXEC @Return = sp_Insert_Eventi
										@Id_Tipo_Evento		= 36,
										@Id_Partizione		= 3701, --L'EVENTO ESCE SEMPRE QUI ANCHE IN CASO DI INGOMBRANTI 30/09 RIUNIONE CON BORTONDELLO/CORENGIA
										@Id_Tipo_Messaggio	= 1100,
										@XmlMessage			= @XmlParam,
										@Id_Processo		= @Id_Processo,
										@Origine_Log		= @Origine_Log,
										@Id_Utente			= @Id_Utente,
										@Errore				= @Errore			OUTPUT

								IF @Return <> 0
									RAISERROR(@Errore,12,1)
							END

							FETCH NEXT FROM Disp_UDC_C INTO
								@ID_UDC,
								@ID_UDC_DETTAGLIO,
								@Qta_Pezzi,
								@WBS_RIFERIMENTO,
								@Id_Partizione
						END

						CLOSE Disp_UDC_C
						DEALLOCATE Disp_UDC_C
					END
				END

				UPDATE	l3integration.Quality_Changes
				SET		Id_Tipo_Stato_Messaggio = 3
				WHERE	ID = @ID

			END TRY
			BEGIN CATCH
				DECLARE @Msg VARCHAR(MAX)

				UPDATE	l3integration.Quality_Changes
				SET		Id_Tipo_Stato_Messaggio = 9
				WHERE	ID = @ID

				SET @Msg = CONCAT('ERRORE NEL PROCESSARE RECORD QUALITY CHANGES ID: ', @ID,
									' ARTICOLO : ', @Id_Articolo_C, ' CONTROL LOT: ', @CONTROL_LOT_C, ' MOTIVO: ', ERROR_MESSAGE())
				EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 4,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @Msg,
							@Errore				= @Errore OUTPUT;
			END CATCH

			FETCH NEXT FROM Cursore_QualChanges INTO
				@ID,
				@CONTROL_LOT_C,
				@Id_Articolo_C,
				@QUANTITY_C,
				@STAT_QUAL_OLD_C,
				@STAT_QUAL_NEW_C
		END

		CLOSE Cursore_QualChanges
		DEALLOCATE Cursore_QualChanges

		DECLARE @TEMPO INT = DATEDIFF(MILLISECOND,@START,GETDATE())

		IF @TEMPO > 500
		BEGIN
			DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Import Quality Changes - TEMPO IMPIEGATO ', @TEMPO)
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
