SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROC [dbo].[sp_Update_Stato_Missioni]
	@Id_Missione		INT,
	@Id_Stato_Missione	VARCHAR(3),
	-- Parametri Standard;
	@Id_Processo		VARCHAR(30),
	@Origine_Log		VARCHAR(25),
	@Id_Utente			VARCHAR(32),	
	@Errore				VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT OFF;

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(30)
	DECLARE @TranCount				INT
	DECLARE @Return					INT

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		-- Dichiarazioni Variabili;
		DECLARE @ID_PARTIZIONE_SORGENTE		INT
		DECLARE @XmlParam					XML
		DECLARE @Id_Tipo_Evento				INT
		DECLARE @Id_Udc						INT
		DECLARE @Codice_Udc					VARCHAR(50)
		DECLARE @Id_Tipo_Missione			VARCHAR(3)
		DECLARE @Tipo_Cella_Dest			VARCHAR(2)
		DECLARE @Id_Partizione_Destinazione INT
		DECLARE @Id_Tipo_Udc				VARCHAR(1)
		DECLARE @IdTestataLista				INT = 0
		DECLARE @xml_param					XML
		-- Dichiarazione Procedure;

		-- Inserimento del codice
		IF @Id_Stato_Missione NOT IN ('ELA','ESE')
		BEGIN
			SELECT	@Id_Udc						= M.Id_Udc,
					@Codice_Udc					= UT.Codice_Udc,
					--Custom Adige
					@Id_Tipo_Udc				= UT.Id_Tipo_Udc,
					@Id_Tipo_Missione			= M.Id_Tipo_Missione,
					@Id_Partizione_Destinazione = Destinazione.Id_Partizione,
					@Tipo_Cella_Dest			= Destinazione.ID_TIPO_PARTIZIONE,
					@XmlParam					= T2.Loc.query('.'),
					@XML_PARAM					= M.Xml_Param,
					@id_partizione_sorgente		= M.Id_Partizione_Sorgente
			FROM	Missioni					M
			LEFT
			JOIN	Udc_Testata					UT
			ON		UT.Id_Udc = M.Id_Udc
			JOIN	Partizioni					Sorgente
			ON		Sorgente.Id_Partizione = M.Id_Partizione_Sorgente
			LEFT
			JOIN	Percorso					PERC
			ON		PERC.Id_Percorso = M.Id_Missione
			JOIN	Partizioni					Destinazione
			ON		Destinazione.Id_Partizione = ISNULL(PERC.Id_Partizione_Destinazione,M.Id_Partizione_Destinazione)
			OUTER
			APPLY	M.XML_PARAM.nodes('//ERRORECS') as T2(Loc)
			WHERE	Id_Missione = @Id_Missione
			ORDER
				BY	Sequenza_Percorso ASC

			DELETE	Messaggi_Percorsi
			WHERE	Id_Percorso = @Id_Missione

			-- Se la missione è in qualsiasi stato che non sia "elaborata" o "in esecuzione" pulisco i percorsi.
			DELETE	Percorso
			WHERE	Id_Percorso = @Id_Missione

			IF @Id_Stato_Missione = 'NEW'
			BEGIN
				-- SE è NUOVA LA RICALCOLO.
				BEGIN TRY
					DECLARE @PROC VARCHAR (50) = 'sp_Cerca_Percorso'

					SAVE TRANSACTION @PROC

					EXEC sp_Cerca_Percorso
							@Id_Partizione_Sorgente		= @ID_PARTIZIONE_SORGENTE,
							@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
							@Id_Missione				= @Id_Missione,
							@Steps						= @Xml_Param,
							@Id_Tipo_Missione			= @Id_Tipo_Missione,
							@Id_Processo				= @Id_Processo,
							@Origine_Log				= @Origine_Log,
							@Id_Utente					= @Id_Utente,
							@Errore						= @Errore			OUTPUT

					UPDATE	Missioni
					SET		Id_Stato_Missione = 'ELA'
					WHERE	Id_Missione = @Id_Missione
				END TRY
				BEGIN CATCH
					SELECT ERROR_NUMBER()

					IF ERROR_NUMBER() IN (1222,1205)
						THROW
					ELSE
					BEGIN
						IF XACT_STATE() = 1
							ROLLBACK TRANSACTION @PROC
						ELSE
							THROW

						EXEC @Return = sp_Update_Stato_Missioni
									@Id_Missione		= @Id_Missione,
									@Id_Stato_Missione	= 'IMP',
									@Id_Processo		= @Id_Processo,
									@Origine_Log		= @Origine_Log,
									@Id_Utente			= @Id_Utente,
									@Errore				= @Errore OUTPUT

						IF @Return <> 0
							RAISERROR(@Errore,12,1)
					END
				END CATCH
			END
			ELSE
			BEGIN
				-----CUSTOM ADIGE
				DECLARE @QuotaDps INT	= NULL

				SELECT	@QuotaDps = QUOTADEPOSITOX
				FROM	Missioni
				WHERE	Id_Missione = @Id_Missione

				INSERT INTO Missioni_Storico
					(Id_Missione, Id_Udc,Codice_Udc, Id_Tipo_Missione, ID_PARTIZIONE_SORGENTE, Sorgente, ID_PARTIZIONE_DESTINAZIONE, Destinazione, Stato_Missione, QuotaDeposito, MOTIVO_RCS)
				VALUES
					(@Id_Missione, @Id_Udc, @Codice_Udc, @Id_Tipo_Missione, @ID_PARTIZIONE_SORGENTE, NULL, @Id_Partizione_Destinazione,  NULL, @Id_Stato_Missione, @QuotaDps, @XML_PARAM)

				DELETE	Missioni
				WHERE	Id_Missione = @Id_Missione
				
				DECLARE @StatoLista								INT
				DECLARE @Id_Partizione_Destinazione_Ingresso	INT = 2110
				DECLARE @Id_Tipo_Missione_Ingresso				VARCHAR(3) = 'ING'
				
				-- Se lo stato è "terminata ok" apro le maschere se lo devo fare.
				IF @Id_Stato_Missione = 'TOK'
				BEGIN
					IF (@Id_Tipo_Missione = 'RCS')
						BEGIN
							IF ISNULL(@XML_PARAM.value('data(//BARCODE)[1]','VARCHAR(MAX)'),'') = 'BARCODE NON LETTO'
								BEGIN
									SET @Id_Tipo_Evento = 99
								END
							ELSE
								SET @Id_Tipo_Evento = 1
						END
					ELSE IF (@Id_Tipo_Missione = 'OUL')
					BEGIN
						--PER RISOLVERE IL PROBLEMA DI UNA STESSA UDC STESSO CODICE MA LISTE DIVERSE
						--RECUPERO LA TESTATA DELLA LISTA ATTIVA IN QUEL MOMENTO
						SELECT	@IdTestataLista = mpd.Id_Testata_Lista,
								@StatoLista = tlp.Stato
						FROM	Missioni_Picking_Dettaglio		MPD
						JOIN	Custom.TestataListePrelievo		TLP
						ON		TLP.ID = MPD.Id_Testata_Lista
						WHERE	MPD.Id_Udc = @Id_Udc
							AND MPD.Id_Partizione_Destinazione = @Id_Partizione_Destinazione
							AND MPD.Id_Stato_Missione = 2
							AND ISNULL(MPD.FL_MANCANTI,0) = 0

						IF (@StatoLista = 5)
						BEGIN
							--SE E' UN UDC DI TIPO A 
							IF (@Id_Tipo_Udc IN ('1', '2', '3'))
							BEGIN
								EXEC @Return = dbo.sp_Insert_CreaMissioni
											@Id_Udc						= @Id_Udc,
											@Id_Partizione_Destinazione = @Id_Partizione_Destinazione_Ingresso,
											@XML_PARAM					= '',
											@Id_Tipo_Missione			= @Id_Tipo_Missione_Ingresso,
											@Id_Processo				= @Id_Processo,
											@Origine_Log				= @Origine_Log,
											@Id_Utente					= @Id_Utente,
											@Errore						= @Errore			OUTPUT

								IF (ISNULL(@Errore, '') <> '')
									THROW 50006, @Errore, 1
								--CONTROLLO SUCCESSIVO SE L'UDC NON E COINVOLTA NELL ALTRA BAIA PER LA LISTA DI PRELIEVO
							END

							--SETTO A STATO 1 LA MISSIONE CHE QUANDO SARA A MAGAZZINO POTRA ESSERE RISCHEDULATA SE LA TESTATA TORNA IN STATO ATTIVO
							UPDATE	Missioni_Picking_Dettaglio
							SET		Id_Stato_Missione = 1,
									DataOra_UltimaModifica = GETDATE()
							WHERE	Id_Udc = @Id_Udc
								AND Id_Partizione_Destinazione = @Id_Partizione_Destinazione
								AND Id_Stato_Missione = 2
						END
						ELSE
						BEGIN
							SET @Id_Tipo_Evento = 4
							SET @XmlParam = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc><Id_Testata_Lista>', @IdTestataLista ,'</Id_Testata_Lista></Parametri>')
						END
					END
					--Missione di Outbound/Picking Manuale
					ELSE IF (@Id_Tipo_Missione IN ('OUP','OUT'))
					BEGIN
						SET @Id_Tipo_Evento =	CASE
													--Se sono in 3B03 e ho un Udc di tipo B avvio l'evento di picking manuale
													WHEN @Id_Partizione_Destinazione = 3203 --AND (@Id_Tipo_Udc IN ('4', '5', '6')))
																THEN 3
													--Se sono un Udc di tipo A avvio il picking manuale esclusivamente in 3D04 e 3F04 E 3G01
													WHEN (@Id_Partizione_Destinazione IN (3404, 3604, 3701) AND (@Id_Tipo_Udc IN ('1', '2', '3')))	THEN 3
													ELSE NULL
												END
						SET @XmlParam = '<Parametri/>'
						SET @XmlParam.modify('insert <Id_Udc>{sql:variable("@Id_Udc")}</Id_Udc> into (//Parametri)[1]')
					END
					--Se è una missione di uscita completa
					ELSE IF (@Id_Tipo_Missione = 'OUC')
					BEGIN
						--PER RISOLVERE IL PROBLEMA DI UNA STESSA UDC STESSO CODICE MA LISTE DIVERSE 
						--RECUPERO LA TESTATA DELLA LISTA ATTIVA IN QUEL MOMENTO						
						SELECT	@IdTestataLista = MPD.Id_Testata_Lista,
								@StatoLista = TLP.Stato
						FROM	Missioni_Picking_Dettaglio		MPD
						JOIN	Custom.TestataListePrelievo		TLP
						ON		TLP.ID = MPD.Id_Testata_Lista
						WHERE	MPD.Id_Udc = @Id_Udc
							AND MPD.Id_Partizione_Destinazione = @Id_Partizione_Destinazione
							AND MPD.Id_Stato_Missione = 2
							AND ISNULL(MPD.FL_MANCANTI,0)=0

						--SE LA LISTA E SOSPESA
						IF (@StatoLista = 5)
						BEGIN
							--SE E' UN UDC DI TIPO A
							IF (@Id_Tipo_Udc IN ('1', '2', '3'))
							BEGIN
								EXEC @Return = dbo.sp_Insert_CreaMissioni
											@Id_Udc						= @Id_Udc,
											@Id_Partizione_Destinazione = @Id_Partizione_Destinazione_Ingresso,
											@XML_PARAM					= '',
											@Id_Tipo_Missione			= @Id_Tipo_Missione_Ingresso,
											@Id_Processo				= @Id_Processo,
											@Origine_Log				= @Origine_Log,
											@Id_Utente					= @Id_Utente,
											@Errore						= @Errore		OUTPUT

								IF (ISNULL(@Errore, '') <> '')
										THROW 50006, @Errore, 1
							END

							--SETTO A STATO 1 LA MISSIONE CHE QUANDO SARA A MAGAZZINO POTRA ESSERE RISCHEDULATA SE LA TESTATA TORNA IN STATO ATTIVO
							UPDATE	Missioni_Picking_Dettaglio
							SET		Id_Stato_Missione = 1,
									DataOra_UltimaModifica = GETDATE()
							WHERE	Id_Udc = @Id_Udc
								AND Id_Partizione_Destinazione = @Id_Partizione_Destinazione
								AND Id_Stato_Missione = 2
						END
						ELSE
						BEGIN
							SET @Id_Tipo_Evento = 35
							SET @XmlParam = CONCAT	(
														'<StoredProcedure ProcedureKey="ScaricaUdcPicking">
															<ActionParameter>
																<Parameter>
																	<ParameterName>Id_Udc</ParameterName>
																	<ParameterValue>',@Id_Udc,'</ParameterValue>
																</Parameter>
															</ActionParameter>
														</StoredProcedure>'
													)
						END
					END
					--Se è una missione di specializzazione
					ELSE IF (@Id_Tipo_Missione = 'SPC')
					BEGIN
						--Incremento il numero di uscite per l'udc
						UPDATE	Custom.MissioniSpecializzazioneDettaglio
						SET		N_Uscite = N_Uscite + 1
						WHERE	Id_Udc = @Id_Udc
							AND Id_Partizione_Destinazione = @Id_Partizione_Destinazione

						SET @Id_Tipo_Evento = 33
						SET @XmlParam = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc></Parametri>')
					END
					--Se è una missione tra magazzini
					ELSE IF (@Id_Tipo_Missione = 'MTM')
					BEGIN
						DECLARE @IdUdcTerra int = NULL; 
						--SELECT @IdUdcTerra = ut.Id_Udc FROM Missioni m INNER JOIN Udc_Testata ut ON ut.Id_Udc = m.Id_Udc
						----Se è finita elimino l'Udc associata A TERRA se esiste
						--IF (@IdUdcTerra IS NOT NULL)
						--BEGIN
						--	EXEC @Return = sp_Delete_EliminaUdc @Id_Udc = @IdUdcTerra
						--							,@Id_Processo = @Id_Processo
						--							,@Origine_Log = @Origine_Log
						--							,@Id_Utente = @Id_Utente
						--							,@Errore = @Errore OUTPUT
						--END
					END
					ELSE IF (@Id_Tipo_Missione = 'CQL')
					BEGIN
						SET @Id_Tipo_Evento = 37;
						SET @XmlParam = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc></Parametri>');
					END
					--Uscita lista kitting
					ELSE IF (@Id_Tipo_Missione = 'OUK')
					BEGIN
						SET @Id_Tipo_Evento = 39
						--PER RISOLVERE IL PROBLEMA DI UNA STESSA UDC STESSO CODICE MA LISTE DIVERSE --RECUPERO LA TESTATA DELLA LISTA ATTIVA IN QUEL MOMENTO
						SELECT	@IdTestataLista = Id_Testata_Lista
						FROM	Missioni_Picking_Dettaglio
						WHERE	Id_Udc = @Id_Udc
							AND Id_Partizione_Destinazione = @Id_Partizione_Destinazione
							AND Id_Stato_Missione IN (2)

						SET @XmlParam = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc><Id_Testata_Lista>', @IdTestataLista ,'</Id_Testata_Lista></Parametri>')
					END
					ELSE IF (@Id_Tipo_Missione = 'OUM')
					BEGIN
						DECLARE @ID_ARTICOLO INT

						SELECT	@ID_ARTICOLO = Id_Articolo
						FROM	Missioni_Picking_Dettaglio
						WHERE	Id_Udc = @Id_Udc
							AND Id_Partizione_Destinazione = @Id_Partizione_Destinazione
							AND Id_Stato_Missione = 2
							AND ISNULL(FL_MANCANTI,0) = 1

						SET @Id_Tipo_Evento = 36
						SET @XmlParam = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc><Id_Articolo>',@Id_Articolo,'</Id_Articolo><Missione_Modula>',0,'</Missione_Modula></Parametri>');
					END
					ELSE IF @Id_Tipo_Missione = 'WBS'
					BEGIN
						DECLARE @Id_UdcDettaglio INT
						SELECT	@Id_UdcDettaglio = Id_UdcDettaglio
						FROM	Custom.Missioni_Cambio_WBS
						WHERE	Id_Udc = @Id_Udc
							AND Id_Missione = @Id_Missione

						SET @Id_Tipo_Evento = 46
						SET @XmlParam = CONCAT('<Parametri><Id_UdcDettaglio>',@Id_UdcDettaglio,'</Id_UdcDettaglio></Parametri>')
					END

					IF @Id_Tipo_Evento IS NOT NULL
					BEGIN
						-- Creazione dell'evento solo se la  missione è terminata,altrimenti do il Confirm.
						EXEC @Return = sp_Insert_Eventi
										@Id_Tipo_Evento		= @Id_Tipo_Evento,
										@Id_Partizione		= @Id_Partizione_Destinazione,
										@Id_Tipo_Messaggio	= 1100,
										@XmlMessage			= @XmlParam,
										@Id_Processo		= @Id_Processo,
										@Origine_Log		= @Origine_Log,
										@Id_Utente			= @Id_Utente,
										@Errore				= @Errore OUTPUT;

						IF @Return <> 0
							RAISERROR(@Errore,12,1);
					END
				END
			END
		END
		ELSE
			UPDATE	Missioni
			SET		Id_Stato_Missione = @Id_Stato_Missione,
					Data_Ultima_modifica = GETDATE()
			WHERE	Id_Missione = @Id_Missione

		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION;
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
			
			EXEC sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= @Nome_StoredProcedure,
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 4,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @Errore,
					@Errore				= @Errore OUTPUT;
			-- Return 0 se la procedura è andata in errore;
			RETURN 1;
		END
		ELSE
			THROW;
	END CATCH;
END;
GO
