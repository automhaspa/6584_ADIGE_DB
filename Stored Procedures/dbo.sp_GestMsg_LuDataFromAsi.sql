SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_GestMsg_LuDataFromAsi]
	@Id_Messaggio	INT,
	-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(32),
	@Errore			VARCHAR(500) OUTPUT
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
       -- Recupero i parametri che mi hanno passato
		DECLARE @Id_Partizione_Attuale	INT
		DECLARE @XmlMessage				XML
		DECLARE @Id_Tipo_Messaggio		VARCHAR(5)
		DECLARE @Id_Udc					INT
		DECLARE @QUOTADEPOSITOX			INT = NULL
		DECLARE @Id_Partizione_AT		INT --MI SALVO LA PARTIZIONE DA CUI STA RIENTRANDO, COSI IN CASO DI MANCANCANZA DI SPAZIO RIMETTO LI L'UDC E NON PERDO I DATI

		SELECT	@Id_Partizione_Attuale = Id_Partizione,
				@XmlMessage = Messaggio,
				@Id_Tipo_Messaggio = ID_TIPO_MESSAGGIO
		FROM	Messaggi_Ricevuti
		WHERE	ID_MESSAGGIO = @Id_Messaggio

		-- Dall xml porto a casa i valori che mi servono (dimensionali + id del messaggio a cui rispondere)
		DECLARE @Data_Confirm			INT				= @XmlMessage.value('data(//LU_DATA_CONFIRM)[1]','int')
		DECLARE @Data_Error				INT				= @XmlMessage.value('data(//LU_DATA_ERROR_CODE)[1]','int')
		DECLARE @Altezza				INT				= @XmlMessage.value('data(//LU_HEIGHT)[1]','int')
		DECLARE @Larghezza				INT				= @XmlMessage.value('data(//LU_WIDTH)[1]','int')
		DECLARE @Profondita				INT				= @XmlMessage.value('data(//LU_LENGTH)[1]','int')
		DECLARE @Surplus_Altezza		INT				= @XmlMessage.value('data(//LU_HEIGTH_SURPLUS)[1]','int')
		DECLARE @Surplus_Larghezza_1	INT				= @XmlMessage.value('data(//LU_WIDTH_SIDE_1_SURPLUS)[1]','int')
		DECLARE @Surplus_Larghezza_2	INT				= @XmlMessage.value('data(//LU_WIDTH_SIDE_2_SURPLUS)[1]','int')
		DECLARE @Surplus_Profondita_1	INT				= @XmlMessage.value('data(//LU_LENGTH_SIDE_1_SURPLUS)[1]','int')
		DECLARE @Surplus_Profondita_2	INT				= @XmlMessage.value('data(//LU_LENGTH_SIDE_2_SURPLUS)[1]','int')

		--HA SEMPRE FUNZIONATO SCRITTO COSI QUINDI VA BENE
		DECLARE @Peso					DECIMAL(5,2)	= @XmlMessage.value('data(//LU_WEIGTH)[1]','int')
	    DECLARE @UdcDataRqToL1_Id		INT				= @XmlMessage.value('data(//LuDataRqToAsi_Id)[1]','int')

		-- Ricavo la posizione in cui mi trovo dal passo del percorso appena eseguito e i parametri della missione. Chiudo la missione in esecuzione.
		DECLARE @Id_Missione			INT
		DECLARE @Sequenza_Percorso		INT
		DECLARE @IdTipoMissione			VARCHAR(3) = ''

		--Recupero le informazioni della missione passando dal  <LuDataRqToAsi_Id>
		SELECT  @Id_Missione		= Id_Percorso,
				@Sequenza_Percorso	= Sequenza_Percorso,
				@Id_Udc				= Id_Udc
		FROM	Messaggi_Percorsi
		WHERE	Id_Messaggio = @UdcDataRqToL1_Id

		--recupero eventuali informazioni se per caso in rejection hanno messo un codice udc
		DECLARE @XmlParamMissione XML
		SELECT	@XmlParamMissione = Xml_Param
		FROM	dbo.Missioni
		WHERE	Id_Missione = @Id_Missione	

		--BARCODE DEL BANCALE
		DECLARE @Barcode VARCHAR(17)		=	ISNULL	(
															NULLIF(@XmlMessage.value('data(//LU_CODE)[1]','varchar(17)'),'NOREAD'),
															@XmlParamMissione.value('data(//Codice_Udc)[1]','varchar(17)')
														)

		--Recupero il tipo  della missione in corso
		SELECT	@IdTipoMissione = Id_Tipo_Missione
		FROM	Missioni
		WHERE	Id_Missione = @Id_Missione

		EXEC @Return = dbo.sp_Update_Aggiorna_Posizione_Udc
				@Id_Missione		= @Id_Missione,
				@Sequenza_Percorso	= @Sequenza_Percorso,
				@Id_Stato_Percorso	= 3,
				@Id_Processo		= @Id_Processo,
				@Origine_Log		= @Origine_Log,
				@Id_Utente			= @Id_Utente,
				@Errore				= @Errore			OUTPUT

		-- Controllo valori Dimensionali
		DECLARE @ERRORECS		VARCHAR(MAX) = ''

		IF @Data_Error > 0 OR @Data_Confirm <> 1
			SET @ERRORECS += '<Data>RICHIESTA DATI NON VALIDA</Data>'
		IF @Altezza = 9999
			SET @ERRORECS += '<Height>RILEVATA ALTEZZA MAGGIORE DI QUELLA CONSENTITA </Height>'
		IF @Surplus_Altezza = 9999
			SET @ERRORECS += '<Height>SURPLUS ALTEZZA RILEVATO </Height>'
		IF @Larghezza = 9999
			SET @ERRORECS += '<Width>RILEVATA LARGHEZZA MAGGIORE DI QUELLA CONSENTITA </Width>'
		IF @Surplus_Larghezza_1 = 9999
			SET @ERRORECS += '<Width>RILEVATA LARGHEZZA MAGGIORE DI QUELLA CONSENTITA </Width>'
		IF @Surplus_Larghezza_2 = 9999
			SET @ERRORECS += '<Width>RILEVATA LARGHEZZA MAGGIORE DI QUELLA CONSENTITA </Width>'
		IF @Profondita = 9999
			SET @ERRORECS += '<Length>RILEVATA PROFONDITA MAGGIORE DI QUELLA CONSENTITA </Length>'
		IF @Surplus_Profondita_1 = 9999
			SET @ERRORECS += '<Length>RILEVATA PROFONDITA MAGGIORE DI QUELLA CONSENTITA  </Length>'
		IF @Surplus_Profondita_2 = 9999
			SET @ERRORECS += '<Length>RILEVATA PROFONDITA MAGGIORE DI QUELLA CONSENTITA </Length>'

		--Recupero l'Id_Tipo_Udc corretto  e il peso massimo per quella categoria --TOLLERANZA DI 50 mm
		DECLARE @Tolleranza			INT			= 50
		DECLARE @Id_Tipo_Udc		VARCHAR(1)	= NULL
		DECLARE @PesoMax			INT

		SELECT	@Id_Tipo_Udc = Id_Tipo_Udc,
				@PesoMax = Peso_Max
		FROM	Tipo_Udc
		WHERE	(Altezza >= (@Altezza - @Tolleranza) AND Altezza <= (@Altezza + @Tolleranza))
			AND	(Larghezza >= (@Larghezza - @Tolleranza) AND Larghezza <= (@Larghezza + @Tolleranza))
			AND	(Profondita >= (@Profondita - @Tolleranza) AND Profondita <= (@Profondita + @Tolleranza))

		--Se non riesco a ricondurlo a un tipo UDC predefinito lancio l'eccezione
		IF ISNULL(@Id_Tipo_Udc, '') = ''
			SET @ERRORECS += '<DATA>DIMENSIONI RILEVATE INGONGRUENTI CON LE TIPOLOGIE PREVISTE. IMPOSSIBILE RICONDURRE LE MISURE A UN TIPO PREDEFINITO</DATA>'

		--Controllo del Peso basandomi sul PesoMax presente nella tabella TipoUdc
		IF @Peso > @PesoMax
			SET @ERRORECS += '<WEIGHT>RILEVATO PESO SUPERIORE A 500 KG</WEIGHT>'

		--Controllo che il barcode sia stato letto se non sono in navetta
		IF @Id_Partizione_Attuale <> 2110
        BEGIN
			IF	ISNULL(@Barcode, '') = ''
					OR
				@Barcode = 'NOREAD'
				--SET @Barcode = CAST(CAST(RAND(CAST(NEWID() AS VARBINARY(100)))*10000000 AS INT) AS VARCHAR(25))
				SET @ERRORECS += '<BARCODE>BARCODE NON LETTO</BARCODE>'
        END

		-- Setto i valori di default della nuova missione
		DECLARE @Id_Tipo_Missione				VARCHAR(3) = 'ING'
		DECLARE @Id_Partizione_Destinazione		INT
		DECLARE @ErroreCompleto					VARCHAR(MAX)

		-- Se non ci sono stati errori chiedo una possibile destinazione nel magazzino
		IF @ERRORECS = ''
		BEGIN
			--Se sto entrando da 3A02 faccio l'update anche del Barcode
			IF	@Id_Partizione_Attuale = 3102
				AND
				NOT EXISTS (SELECT TOP 1 1 FROM dbo.Udc_Dettaglio WHERE ID_Udc = @Id_Udc)
			BEGIN
				--Se ho un barcode duplicato verifico anche l'area Terra.
				IF EXISTS(SELECT TOP 1 1 FROM Udc_Testata WHERE Codice_Udc = @Barcode AND ID_UDC <> @Id_Udc)
				BEGIN
					DECLARE @IdTipoPartizione	VARCHAR(2)
					DECLARE	@Id_UdcTerra		INT

					--Controllo  se è un rientro da area a terra
					SELECT	@IdTipoPartizione	= ISNULL(P.ID_TIPO_PARTIZIONE,''),
							@Id_UdcTerra		= ISNULL(UT.Id_Udc,0),
							@Id_Partizione_AT	= UP.Id_Partizione
					FROM	Udc_Testata		UT
					JOIN	Udc_Posizione	UP
					ON		UT.Id_Udc = UP.Id_Udc
					JOIN	Partizioni		P
					ON		P.ID_PARTIZIONE = UP.Id_Partizione
					WHERE	Codice_Udc = @Barcode

					--Se ho lo stesso barcode in area terra allora e ho la missione di rientro sposto l'UDC da terra a magazzino
					IF @IdTipoPartizione IN ('AT','MI') AND @IdTipoMissione = 'INT'
					BEGIN
						--Elimino l'UDC appena creata
						EXEC @Return = sp_Delete_EliminaUdc
									@Id_Udc			= @Id_Udc,
									@Id_Processo	= @Id_Processo,
									@Origine_Log	= @Origine_Log,
									@Id_Utente		= @Id_Utente,
									@Errore			= @Errore			OUTPUT

						--Aggiorno la posizione di quella a terra alla rulliera attuale (3A02)
						UPDATE	Udc_Posizione
						SET		Id_Partizione = 3102
						WHERE	Id_Udc = @Id_UdcTerra

						--Cambio L'ID udc gestita in questo momento
						SET @Id_Udc = @Id_UdcTerra
					END

					--Non deve arrivare da packing list
					ELSE IF @IdTipoPartizione = 'AP' AND @IdTipoMissione = 'INT'
						SET @ERRORECS = '<CODICE_UDC>Barcode legato ad un''UDC di una Packing List. Eliminare l''Udc.</CODICE_UDC>'
					ELSE
						SET @ERRORECS = CONCAT('<CODICE_UDC>Codice Barcode: ',@BARCODE, ' già presente su un''UDC in magazzino</CODICE_UDC>')
				END
				--Se non ho l'UDC in area terra ma sono una missione di rientro vado in reject con l'eccezione
				ELSE IF @IdTipoMissione = 'INT'
							AND
						NOT EXISTS(SELECT TOP 1 1 FROM Udc_Testata WHERE Codice_Udc = @Barcode)
					SET @ERRORECS = '<CODICE_UDC>Selezionato rientro da Area Terra di un''UDC non presente a Terra.</CODICE_UDC>'
				--Se non ho barcode duplicati aggiorno il codice UDC
				ELSE
				BEGIN
					UPDATE	Udc_Testata
					SET		Codice_Udc = @Barcode
					WHERE	Id_Udc= @Id_Udc

					--Aggiorno la lista barcode e lo escludo
					UPDATE	Custom.AnagraficaBancali
					SET		Stato = 2
					WHERE	Codice_Barcode = @Barcode
				END
			END

			--Se sono in rientro da navetta la misura del bancale può essere cambiata perciò faccio l'update
			UPDATE	Udc_Testata
			SET		Id_Tipo_Udc	= @Id_Tipo_Udc,
					Altezza		= @Altezza,
					Larghezza	= @Larghezza,
					Profondita	= @Profondita,
					Peso		= @Peso
			WHERE	Id_Udc = @Id_Udc

			BEGIN TRY
				--Cerco una destinazione
				EXEC @Id_Partizione_Destinazione = [dbo].[sp_Output_PropostaUbicazione]
							@Id_Udc			= @Id_Udc,
							@QUOTADEPOSITOX = @QUOTADEPOSITOX	OUTPUT,
							@Id_Processo	= @Id_Processo,
							@Origine_Log	= @Origine_Log,
							@Id_Utente		= @Id_Utente,
							@Errore			= @Errore			OUTPUT
			END TRY
			BEGIN CATCH
				SET @ERRORECS = CONCAT('<Ubicazione>PROPOSTA UBICAZIONE FALLITA. EX',@@ERROR,'</Ubicazione>')
			END CATCH

			IF ISNULL(@Id_Partizione_Destinazione,0) = 0
				SET @ERRORECS = '<Ubicazione>PROPOSTA UBICAZIONE FALLITA. SPAZIO INSUFFICIENTE </Ubicazione>'

			SET @ErroreCompleto = @ERRORECS
		END
		
		-- Se ci sono stati errori converto la missione da creare in Reject
		IF @ERRORECS <> ''
		BEGIN

			DECLARE @RIENTRO_AREATERRA BIT = 0

			IF @Id_Partizione_AT IS NOT NULL AND ISNULL(@IdTipoMissione,'ING') = 'INT'
				SET @RIENTRO_AREATERRA = 1

			-- Imposto i tipo missione a rejection
			SET @Id_Tipo_Missione = 'RCS'

			--Seleziono la partizione di rejection dal Id_Partizione_OUT
			SELECT	@Id_Partizione_Destinazione = Id_Partizione_OUT
			FROM	dbo.Procedure_Personalizzate_Gestione_Messaggi
			WHERE	Id_Partizione = @Id_Partizione_Attuale
				AND	Id_Tipo_Messaggio = @Id_Tipo_Messaggio
				
			--In caso di reject dopo rientro da area terra rimetto l'UDC a terra cosi da non perdere i dati e ne creo una fittizia sulla partizione attuale da portare in reject
			IF @RIENTRO_AREATERRA = 1
			BEGIN
				DECLARE @Id_Udc_Nuova INT

				UPDATE	Udc_Posizione
				SET		Id_Partizione = @Id_Partizione_AT
				WHERE	Id_Udc = @Id_Udc
				
				EXEC sp_Insert_Crea_Udc
						@Id_Partizione	= @Id_Partizione_Attuale,
						@Id_Udc			= @Id_Udc_Nuova			OUTPUT,
						@Id_Processo	= @Id_Processo,
						@Origine_Log	= @Origine_Log,
						@Id_Utente		= @Id_Utente,
						@Errore			= @Errore				OUTPUT

				SET @Id_Udc = @Id_Udc_Nuova

				DECLARE @Descrizione_AT VARCHAR(14)
				SELECT	@Descrizione_AT = DESCRIZIONE
				FROM	Partizioni
				WHERE	ID_PARTIZIONE = @Id_Partizione_AT

				SET @ERRORECS += CONCAT('<UDC_AREA_TERRA>UDC rimessa in area terra ',@Descrizione_AT,'</UDC_AREA_TERRA>')
			END

			--Setto l'errore da mostrare nell'evento di reject
			SET @ErroreCompleto = CONCAT('<ERRORECS>',@ERRORECS,'</ERRORECS>')
		END

		--Creo la missione per l'Udc
		IF NOT EXISTS (SELECT TOP 1 1 FROM Percorso WHERE Id_Percorso = @Id_Missione AND Sequenza_Percorso > @Sequenza_Percorso)
			EXEC @Return = dbo.sp_Insert_CreaMissioni
					@Id_Udc						= @Id_Udc,
                    @Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
                    @QUOTADEPOSITOX				= @QUOTADEPOSITOX,
					@XML_PARAM					= @ErroreCompleto,
                    @Id_Tipo_Missione			= @Id_Tipo_Missione,
                    @Id_Processo				= @Id_Processo,
                    @Origine_Log				= @Origine_Log,
                    @Id_Utente					= @Id_Utente,
                    @Errore						= @Errore					OUTPUT

       --Fine del codice;
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
		   
			EXEC dbo.sp_Insert_Log
						@Id_Processo = @Id_Processo
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
		ELSE
			THROW
	END CATCH
END
GO
