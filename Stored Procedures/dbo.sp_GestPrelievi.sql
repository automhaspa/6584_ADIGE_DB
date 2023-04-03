SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_GestPrelievi]
	@Id_Gruppo_Lista INT = NULL,
	@Stato VARCHAR(10) = NULL,
	@Id_Partizione_Destinazione INT = NULL,
	@Anteprima Bit = 0,
	-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(32),	
	@Errore			VARCHAR(500) OUTPUT
	/*
		@Stato:
			+ ELIMINATO
			+ ESECUZIONE
			+ RIORDINO
			+ SOSPESO
	*/
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
		-- Dichiarazioni Variabili;
		DECLARE @WkTableListToDelete TABLE (
												Id_Missione INT NULL,
												Id_Stato_Missione VARCHAR(3) NULL,
												Id_Udc NUMERIC(18,0) NULL,
												Id_Gruppo_Lista INT NULL,
												Id_Lista INT NULL,
												Id_Dettaglio INT NULL
											)
		
		DECLARE @CursorTasksToDelete CURSOR
			DECLARE	@Id_Missione_Cursor INT

		DECLARE @CursorListItems CURSOR
			DECLARE @Id_Area_Lista_C INT
			DECLARE @Id_Gruppo_Lista_C INT
			DECLARE @Id_Lista_C INT	
			DECLARE @Id_Dettaglio_C INT
			DECLARE @Id_Articolo_C INT
			DECLARE @Lotto_Lista_C VARCHAR(20)
			DECLARE @Quantita_Richiesta_C NUMERIC(18,4)
			DECLARE @Id_Udc_Predefinita_C INT

		DECLARE @CursorUdc CURSOR
			DECLARE @Id_UdcDettaglio_U INT
			DECLARE @Id_Udc_U INT
			DECLARE @Quantita_Udc_U NUMERIC(18,4)
			DECLARE @Lotto_Udc_U VARCHAR(20)

		DECLARE @CursorTasks CURSOR
			DECLARE @Id_Udc_T INT
			DECLARE	@Id_Dettaglio_T INT
			DECLARE	@Id_Partizione_Destinazione_T INT
			DECLARE @Id_Gruppo_Lista_T INT
			
		-- Inserimento del codice;

		-- CONTROLLO CHE CI SIANO I PARAMETRI DI INPUT E CHE NON SIA UNA SCHEDULAZIONE A CHIAMARLA
		IF(@Id_Gruppo_Lista IS NOT NULL AND @Stato IS NOT NULL)
			BEGIN

				-- POPOLO LA TABELLA TEMPORANEA @WkTableListToDelete CON UNA LISTA DELLE MISSIONI, LISTE E DETTAGLI DA CANCELLARE
				INSERT INTO @WkTableListToDelete (Id_Missione,Id_Stato_Missione,Id_Udc,Id_Gruppo_Lista,Id_Lista,Id_Dettaglio)
				SELECT		M.Id_Missione,
							M.Id_Stato_Missione,
							M.Id_Udc,
							LHG.Id_Gruppo_Lista,
							LT.Id_Lista,
							LD.Id_Dettaglio
				FROM		dbo.Lista_Host_Gruppi LHG
				INNER JOIN	dbo.Liste_Testata LT ON LT.Id_Gruppo_Lista = LHG.Id_Gruppo_Lista
				INNER JOIN	dbo.Liste_Dettaglio LD ON LD.Id_Lista = LT.Id_Lista
				LEFT JOIN	dbo.Missioni_Dettaglio MD ON MD.Id_Dettaglio = LD.Id_Dettaglio
				LEFT JOIN	dbo.Missioni M ON M.Id_Udc = MD.Id_Udc
				WHERE		LHG.Id_Gruppo_Lista = @Id_Gruppo_Lista
				AND			(M.Id_Stato_Missione  IN ('NEW','ELA') OR M.Id_Stato_Missione IS NULL)

				-- SCORRO LE POSSIBILI OPZIONI DI @STATO PASSATO IN INPUT
				IF(@Stato IN ('SOSPESO','ELIMINATO'))
					BEGIN
						/*
							PRIMA CANCELLO TUTTE LE EVENTUALI MISSIONI FATTE PARTIRE DA QUELLA LISTA CHE SONO IN STATO 'NUOVO' O 'ELABORATO'. 
							LE MISSIONI IN STATO DI 'ESECUZIONE' VENGONO PORTATE A TERMINE.
						*/
						-- CANCELLO LE MISSIONI METTENDOLE IN STATO 'DEL'
						SET @CursorTasksToDelete = CURSOR LOCAL FAST_FORWARD FOR 
							SELECT	Id_Missione 
							FROM	@WkTableListToDelete
							WHERE	Id_Stato_Missione  IN ('NEW','ELA')
						OPEN @CursorTasksToDelete

						FETCH NEXT FROM @CursorTasksToDelete INTO
							@Id_Missione_Cursor
						WHILE @@FETCH_STATUS = 0
							BEGIN

								EXEC dbo.sp_Update_Stato_Missioni @Id_Missione = @Id_Missione_Cursor,
								                                  @Id_Stato_Missione = 'DEL',
								                                  @Id_Processo = @Id_Processo,
								                                  @Origine_Log = @Origine_Log,
								                                  @Id_Utente = @Id_Utente,
								                                  @Errore = @Errore OUTPUT

								FETCH NEXT FROM @CursorTasksToDelete INTO
								@Id_Missione_Cursor
							END
						CLOSE @CursorTasksToDelete
						DEALLOCATE @CursorTasksToDelete

						/*
							SE @STATO = 'ELIMINATO' ALLORA BISOGNA CANCELLARE TUTTE LE RIGHE DALLE TABELLE DI CONFIGURAZIONE (IN QUESTO ORDINE):
								+ Missioni_Dettaglio
								+ Lista_Uscita_Dettaglio
								+ Liste_Dettaglio
								+ Liste_Testata
								+ Lista_Host_Gruppi
						*/
						IF(@Stato = 'ELIMINATO')
							BEGIN
								--CANCELLO LE MISSIONI_DETTAGLIO
								DELETE FROM dbo.Missioni_Dettaglio WHERE Id_Gruppo_Lista = @Id_Gruppo_Lista

								--CANCELLO LE LISTE_USCITA_DETTAGLIO
								DELETE FROM dbo.Lista_Uscita_Dettaglio WHERE Id_Dettaglio IN (SELECT DISTINCT Id_Dettaglio FROM @WkTableListToDelete)

								--CANCELLO LE LISTE_DETTAGLIO
								DELETE FROM dbo.Liste_Dettaglio WHERE Id_Dettaglio IN (SELECT DISTINCT Id_Dettaglio FROM @WkTableListToDelete)

								--CANCELLO LE LISTE_TESTATA
								DELETE FROM dbo.Liste_Testata WHERE Id_Gruppo_Lista = @Id_Gruppo_Lista

								--CANCELLO IL GRUPPO LISTA
								DELETE FROM dbo.Lista_Host_Gruppi WHERE Id_Gruppo_Lista = @Id_Gruppo_Lista
							END

						/*
							IN CASO CONTRARIO FACCIO UN UPDATE DELLA LISTA_HOST_GRUPPI E DELLA LISTE_TESTATA IN STATO 3 (SOSPESO)
							ED ELIMINO TUTTE LE RIGHE NELLA MISSIONI_DETTAGLIO CHE NON SONO ANCORA STATE PRESE IN CARICO 
							(QUINDI ESCLUDO QUELLE CHE HANNO GIA' L'UDC ASSOCIATA IN UNA MISSIONE IN ESECUZIONE)
						*/
						ELSE	
							BEGIN
								
								DELETE		MD
								FROM		dbo.Missioni_Dettaglio MD
								INNER JOIN	@WkTableListToDelete WK ON WK.Id_Udc = MD.Id_Udc
								WHERE		MD.Id_Gruppo_Lista = @Id_Gruppo_Lista
								AND			WK.Id_Stato_Missione  IN ('NEW','ELA')

                            	UPDATE	dbo.Lista_Host_Gruppi
								SET		Id_Stato_Gruppo = 3
								WHERE	Id_Gruppo_Lista = @Id_Gruppo_Lista
						
								UPDATE	dbo.Liste_Testata
								SET		Id_Stato_Lista = 3
								WHERE	Id_Gruppo_Lista = @Id_Gruppo_Lista

								UPDATE	dbo.Liste_Dettaglio 
								SET		Id_Stato_Articolo = 1
								WHERE	Id_Dettaglio IN (SELECT Id_Dettaglio FROM @WkTableListToDelete)
								
							END	
					END

				ELSE IF (@Stato = 'RIORDINO')
					BEGIN
						RAISERROR('RIORDINO TEMPORANEAMENTE NON GESTITO',12,1)
					END

				ELSE IF (@Stato = 'ESECUZIONE')
					BEGIN
						UPDATE	dbo.Lista_Host_Gruppi
						SET		Id_Stato_Gruppo = 4
						WHERE	Id_Gruppo_Lista = @Id_Gruppo_Lista
						
						UPDATE	dbo.Liste_Testata
						SET		Id_Stato_Lista = 4
						WHERE	Id_Gruppo_Lista = @Id_Gruppo_Lista
					END

				ELSE
					RAISERROR('SpEx_ListStateNotHandled',12,1)


				IF(@Id_Partizione_Destinazione IS NOT NULL)
					UPDATE	dbo.Lista_Host_Gruppi
					SET		Id_Partizione_Destinazione = @Id_Partizione_Destinazione
					WHERE	Id_Gruppo_Lista = @Id_Gruppo_Lista
			END

		/*
			DA QUI IN POI C'E' IL PEZZO DI GESTIONE DELLE LISTE E CREAZIONE DELLE MISSIONI
		*/

		/*
			SETTO IL CURSORE CHE TIRA SU I DETTAGLI DELLE LISTE NON ANCORA PRESI IN CARICO
		*/
		SET @CursorListItems = CURSOR LOCAL FAST_FORWARD FOR
		SELECT	 A.ID_AREA
				,LHG.Id_Gruppo_Lista
				,LD.Id_Lista
				,LD.Id_Dettaglio
				,LD.Id_Articolo
				,LUD.Lotto
				,LD.Qta_Lista - LUD.Qta_Prelevata - ISNULL(Prelievi_Dettaglio.Quantita,0) AS Qta_Prelievo
				,LD.Id_Udc
		FROM	dbo.Liste_Testata LT
				INNER JOIN	dbo.Liste_Dettaglio LD ON LD.Id_Lista = LT.Id_Lista
				INNER JOIN	dbo.Lista_Uscita_Dettaglio LUD ON LUD.Id_Dettaglio = LD.Id_Dettaglio
				INNER JOIN	dbo.Lista_Host_Gruppi LHG ON LHG.Id_Gruppo_Lista = LT.Id_Gruppo_Lista
				LEFT JOIN	(SELECT Id_Dettaglio
									,SUM(Qta_Orig) Quantita
								FROM	dbo.Missioni_Dettaglio 
								GROUP BY Id_Dettaglio) Prelievi_Dettaglio
								ON Prelievi_Dettaglio.Id_Dettaglio = LD.Id_Dettaglio

				INNER JOIN dbo.Partizioni P ON P.ID_PARTIZIONE = LHG.Id_Partizione_Destinazione
				INNER JOIN	dbo.SottoComponenti SC ON SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
				INNER JOIN	dbo.Componenti C  ON C.ID_COMPONENTE = SC.ID_COMPONENTE
				INNER JOIN	dbo.SottoAree SA ON SA.ID_SOTTOAREA = C.ID_SOTTOAREA
				INNER JOIN	dbo.Aree A ON A.ID_AREA = SA.ID_AREA
					
		WHERE	(LT.Id_Gruppo_Lista = @Id_Gruppo_Lista	OR @Id_Gruppo_Lista IS NULL)
				AND (LD.Qta_Lista - LUD.Qta_Prelevata - ISNULL(Prelievi_Dettaglio.Quantita,0)) > 0
				AND LHG.Id_Stato_Gruppo IN (2,4)
		ORDER	BY LD.Id_Articolo ASC

		OPEN @CursorListItems

		FETCH NEXT FROM @CursorListItems INTO 
		 @Id_Area_Lista_C
		,@Id_Gruppo_Lista_C
		,@Id_Lista_C
		,@Id_Dettaglio_C
		,@Id_Articolo_C
		,@Lotto_Lista_C
		,@Quantita_Richiesta_C
		,@Id_Udc_Predefinita_C
		WHILE @@FETCH_STATUS = 0
			BEGIN

				/*
					SETTO UN SECONDO CURSORE CHE ANDRA' A CERCARE LE UDC DEL TRASLO / BOOSTER CHE HANNO ABBASTANZA ARTICOLI DA SODDISFARE LA RICHIESTA.
				*/

				SET	@CursorUdc = CURSOR LOCAL FAST_FORWARD FOR
					SELECT	 UD.Id_UdcDettaglio
							,UD.Id_Udc
							,UD.Quantita_Pezzi - ISNULL(Quantita_Impegnate.Qta_Impegnata,0)
							,UD.Lotto
					FROM	dbo.Udc_Dettaglio UD
							INNER JOIN dbo.Udc_Testata UT ON UT.Id_Udc = UD.Id_Udc
							INNER JOIN dbo.Udc_Posizione UP ON UP.Id_Udc = UD.Id_Udc
							INNER JOIN dbo.Partizioni P ON P.Id_Partizione = UP.Id_Partizione
							INNER JOIN dbo.SottoComponenti SC ON SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
							INNER JOIN dbo.Componenti C  ON C.ID_COMPONENTE = SC.ID_COMPONENTE
							INNER JOIN dbo.SottoAree SA ON SA.ID_SOTTOAREA = C.ID_SOTTOAREA
							INNER JOIN dbo.Aree A ON A.ID_AREA = SA.ID_AREA

							LEFT JOIN  (SELECT	Id_Udc	
												,Id_Articolo
												,Lotto
												,SUM(Qta_Orig) Qta_Impegnata
										FROM	dbo.Missioni_Dettaglio MD
										GROUP BY Id_Udc,Id_Articolo,Lotto) Quantita_Impegnate 
										ON	Quantita_Impegnate.Id_Udc = UD.Id_Udc
											AND Quantita_Impegnate.Id_Articolo = UD.Id_Articolo
											AND Quantita_Impegnate.Lotto = UD.Lotto
							LEFT JOIN	(SELECT Id_Udc FROM dbo.Missioni_Dettaglio WHERE Id_Dettaglio = @Id_Dettaglio_C GROUP BY Id_Udc) Controllo_Udc 
											ON Controllo_Udc.Id_Udc = UD.Id_Udc  			
							LEFT JOIN	(SELECT Id_Udc FROM dbo.Missioni_Dettaglio WHERE Id_Gruppo_Lista = @Id_Gruppo_Lista_C GROUP BY Id_Udc) Ventilazione_Udc
											ON Ventilazione_Udc.Id_Udc = UD.Id_Udc			 	
					WHERE	UD.Id_Articolo = @Id_Articolo_C
							AND ((UD.Lotto = @Lotto_Lista_C AND @Lotto_Lista_C IS NOT NULL) OR (@Lotto_Lista_C IS NULL))
							AND ISNULL(UT.Blocco_Udc,0) = 0
							AND (@Id_Udc_Predefinita_C = UT.Id_Udc OR @Id_Udc_Predefinita_C IS NULL)
							AND (UD.Quantita_Pezzi - ISNULL(Quantita_Impegnate.Qta_Impegnata,0)) > 0
							AND Controllo_Udc.Id_Udc IS NULL
							AND A.ID_AREA =	CASE @Id_Area_Lista_C
												WHEN 1 THEN 3 --SE LA PARTIZIONE DI DESTINAZIONE DELLA LISTA E' IN AREA 1000 ALLORA PRENDO LE UDC DEL MAGAZZINO TRASLO
												WHEN 2 THEN 4 --SE LA PARTIZIONE DI DESTINAZIONE DELLA LISTA E' IN AREA 2000 ALLORA PRENDO LE UDC DEL MAGAZZINO BOOSTER
											END	
					ORDER BY	ISNULL(Ventilazione_Udc.Id_Udc,0) DESC
								,UD.Data_Creazione DESC
								,UD.Quantita_Pezzi DESC

				OPEN @CursorUdc
			
				FETCH NEXT FROM @CursorUdc INTO
					 @Id_UdcDettaglio_U
					,@Id_Udc_U
					,@Quantita_Udc_U
					,@Lotto_Udc_U

				WHILE @@FETCH_STATUS = 0
					BEGIN
						IF @Quantita_Richiesta_C >= @Quantita_Udc_U
						BEGIN
							-- SE LA @Quantita_Richiesta E' MAGGIORE DELLA QUANTITA' PRESENTE NELL'UDC SIGNIFICA CHE NON BASTA QUELL'UDC A SODDISFARE LA RICHIESTA.
							-- INSERISCO LA RIGA NELLA MISSIONI_DETTAGLIO E AGGIORNO LA VARIABILE @Quantita_Richiesta SOTTRAENDO LA @Quantita_Udc E CONTINUO CON IL CICLO FINCHE' NON ARRIVO A 0

							INSERT INTO	dbo.Missioni_Dettaglio (Id_Udc,Id_Lista,Id_Dettaglio,Id_Articolo,Lotto,Quantita,Id_Stato_Articolo,Qta_Orig,Id_Gruppo_Lista,Id_UdcDettaglio)
							VALUES (@Id_Udc_U,@Id_Lista_C,@Id_Dettaglio_C,@Id_Articolo_C,@Lotto_Udc_U,0,1,@Quantita_Udc_U,@Id_Gruppo_Lista_C,@Id_UdcDettaglio_U)
					
							SET @Quantita_Richiesta_C = @Quantita_Richiesta_C - @Quantita_Udc_U
						END
						ELSE
						BEGIN
							-- SE LA @Quantita_Udc E' MAGGIORE O UGUALE ALLA @Quantita_Richiesta SIGNIFICA CHE L'UDC ATTUALE SODDISFA LA RICHIESTA DEL DETTAGLIO.
							-- INSERISCO LA RIGA NELLA MISSIONI DETTAGLIO E SETTO LA @Quantita_Richiesta A 0 PER USCIRE DAL CICLO

							INSERT INTO dbo.Missioni_Dettaglio (Id_Udc,Id_Lista,Id_Dettaglio,Id_Articolo,Lotto,Quantita,Id_Stato_Articolo,Qta_Orig,Id_Gruppo_Lista,Id_UdcDettaglio)
							VALUES (@Id_Udc_U,@Id_Lista_C,@Id_Dettaglio_C,@Id_Articolo_C,@Lotto_Udc_U,0,1,@Quantita_Richiesta_C,@Id_Gruppo_Lista_C,@Id_UdcDettaglio_U)
					
							SET @Quantita_Richiesta_C = 0				
						END
				
						IF @Quantita_Richiesta_C = 0 BREAK -- QUANTO LA @Quantita_Richiesta ARRIVA A 0 SIGNIFICA CHE HO SODDISFATTO LA RICHIESTA DELLA LISTA
						
						FETCH NEXT FROM @CursorUdc INTO 
							 @Id_UdcDettaglio_U
							,@Id_Udc_U
							,@Quantita_Udc_U
							,@Lotto_Udc_U
					END

				CLOSE @CursorUdc
				DEALLOCATE @CursorUdc

				/*
					SE C'E' ALMENO UNA RIGA NELLA MISSIONI_DETTAGLIO PER IL DETTAGLIO DEL CURSORE E NON SI TRATTA DI UN ANTEPRIMA SETTO L'ID_STATO_ARTICOLO A 4
				*/
				IF EXISTS(SELECT 1 FROM dbo.Missioni_Dettaglio WHERE Id_Dettaglio = @Id_Dettaglio_C) AND @Anteprima = 0
					UPDATE dbo.Liste_Dettaglio SET Id_Stato_Articolo = 4 WHERE Id_Dettaglio = @Id_Dettaglio_C

				FETCH NEXT FROM @CursorListItems INTO 
				@Id_Area_Lista_C
				,@Id_Gruppo_Lista_C
				,@Id_Lista_C
				,@Id_Dettaglio_C
				,@Id_Articolo_C
				,@Lotto_Lista_C
				,@Quantita_Richiesta_C
				,@Id_Udc_Predefinita_C
			END

		CLOSE @CursorListItems
		DEALLOCATE @CursorListItems

		/*
			SE IL FLAG DI ANTEPRIMA E' A 0 CREO LE MISSIONI
		*/
		IF (@Anteprima = 0)
			BEGIN
				--POPOLA IL CURSORE CHE PRENDE I DATI CHE MI SERVONO PER CREARE LE MISSIONI PER LE UDC
				SET @CursorTasks = CURSOR LOCAL FAST_FORWARD FOR
					SELECT	MD.Id_Udc
							,MD.Id_Dettaglio
							,LHD.Id_Partizione_Destinazione
							,LHD.Id_Gruppo_Lista
					FROM	dbo.Missioni_Dettaglio MD
							INNER JOIN dbo.Articoli A ON A.Id_Articolo = MD.Id_Articolo
							INNER JOIN dbo.Lista_Host_Gruppi LHD ON LHD.Id_Gruppo_Lista = MD.Id_Gruppo_Lista
					WHERE	MD.Id_Stato_Articolo = 1
							AND LHD.Id_Stato_Gruppo IN (4,5)
							AND NOT EXISTS	(SELECT 1 FROM dbo.Missioni WHERE Id_Stato_Missione IN ('NEW','ELA','ESE') AND Id_Udc = MD.Id_Udc)

				OPEN @CursorTasks

				FETCH NEXT FROM @CursorTasks INTO
					 @Id_Udc_T
					,@Id_Dettaglio_T
					,@Id_Partizione_Destinazione_T
					,@Id_Gruppo_Lista_T

				WHILE @@FETCH_STATUS = 0
					BEGIN

						EXEC dbo.sp_Insert_CreaMissioni 
							@Id_Udc = @Id_Udc_T,                       
							@Id_Partizione_Destinazione = @Id_Partizione_Destinazione_T,    
							@Id_Gruppo_Lista = @Id_Gruppo_Lista_T,               
							@Id_Tipo_Missione = 'OUL',             
							@Xml_Param = '',					
							@Id_Processo = @Id_Processo,                  
							@Origine_Log = @Origine_Log,                  
							@Id_Utente = @Id_Utente,                    
							@Errore = @Errore OUTPUT

						-- SE IL GRUPPO LISTA NON E' ANCORA IN STATO 5 (IN ESECUZIONE) LO ESEGUO
						IF NOT EXISTS(SELECT 1 FROM dbo.Lista_Host_Gruppi WHERE Id_Gruppo_Lista = @Id_Gruppo_Lista_T AND Id_Stato_Gruppo = 5)
						BEGIN
							UPDATE	dbo.Lista_Host_Gruppi
							SET		Id_Stato_Gruppo = 5
							WHERE	Id_Gruppo_Lista = @Id_Gruppo_Lista_T
						
							UPDATE	dbo.Liste_Testata
							SET		Id_Stato_Lista = 5
							WHERE	Id_Gruppo_Lista = @Id_Gruppo_Lista_T
						END

						FETCH NEXT FROM @CursorTasks INTO 
							 @Id_Udc_T
							,@Id_Dettaglio_T
							,@Id_Partizione_Destinazione_T
							,@Id_Gruppo_Lista_T
					END
					
				CLOSE @CursorTasks
				DEALLOCATE @CursorTasks

			END
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
