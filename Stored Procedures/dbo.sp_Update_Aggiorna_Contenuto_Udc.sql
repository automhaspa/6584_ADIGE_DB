SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROC [dbo].[sp_Update_Aggiorna_Contenuto_Udc]
	@Id_Udc					INT				= NULL,
	@Id_UdcDettaglio		INT				= NULL,
	@Id_Articolo			INT				= NULL,
	@Qta_Pezzi_Input		NUMERIC(18,4)	= NULL,
	@Id_Causale_Movimento	INT,
	@Id_UdcContainer		INT				= NULL,
	@Qta_Persistenza_Nuova	INT				= NULL,
	@Matricola				VARCHAR(20)		= '00000000000000000000',
	@Lotto					VARCHAR(20)		= '',
	@Data_Scadenza			DATETIME		= NULL,
	@Id_Gruppo_Lista		INT				= NULL,
	@Id_Lista				INT				= NULL,
	@Id_Dettaglio			INT				= NULL,
	@USERNAME				VARCHAR(32)		= NULL,
	@DOPPIO_STEP_QM			BIT				= NULL,
	@WBS_CODE				VARCHAR(40)		= NULL,
	@CONTROL_LOT			VARCHAR(40)		= NULL,
	@PROD_ORDER				VARCHAR(12)		= NULL,
	--Kitting
	@Kitting				BIT				= 0,
	--Causale FlVoid per annulamento prelievo Modula o per annullamento carico Merce Modula
	@Flag_FlVoid			int				= NULL,
	--Causali Picking Manuale
	@Id_Causale				VARCHAR(4)		= NULL,
	--Parametro Specializzazione
	@Id_Ddt_Reale			int				= NULL,
	@Id_Riga_Ddt			int				= NULL,
	--Campi dedicati al controllo qualità 
	@FlagControlloQualita	BIT = 0,
	@Motivo_CQ				varchar(MAX)	= NULL,

	@FlagNonConforme		BIT = 0,
	@Motivo_NC				VARCHAR(MAX)	= NULL,

	--Parameteri Liste Di prelievo Nuove
	@Id_Riga_Lista			INT				= NULL,
	@Id_Testata_Lista		INT				= NULL,
	--MOVIMENTAZIONE MANUALE CAMPI L3
	@SUPPLIER_CODE			VARCHAR(500)	= NULL,
	@REASON					VARCHAR(500)	= NULL,
	@REF_NUMBER				VARCHAR(500)	= NULL,
	@DOC_NUMBER				VARCHAR(500)	= NULL,
	@RETURN_DATE			DATE			= NULL,
	@NOTES					VARCHAR(150)	= NULL,
	--LA SETTO SOLO QUANDO SPLITTO I DETTAGLIO (EX CAMBIO WBS) IN MODO TALE DA NON PERDERE LA DATA CREAZIONE REALE
	@Data_Creazione			DATETIME		= NULL,

	--Se si tratta di invio a modula in fase di specializzazione non devo MAI inviare consuntivo a SAP ci penserà poi MODULA a consuntivare
	@Invio_Consuntivo		BIT				= 1,
	-- Parametri Standard;
	@Id_Processo			VARCHAR(30),
	@Origine_Log			VARCHAR(25),
	@Id_Utente				VARCHAR(32),	
	@Errore					VARCHAR(500) OUTPUT
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

		-- Inserimento del codice;
		-- Dichiarazioni Variabili;
		DECLARE @ID_UDC_MODULA INT = 702
		DECLARE @Qta_Persistenza_Giacenza INT;
		DECLARE @Qta_Giacenza NUMERIC(18,2);
	
		/*
			SE LA QUANTITA' PASSATA IN INGRESSO E' MINORE O UGUALE A ZERO RITORNO UN ERRORE 
			(A MENO CHE LA CAUSALE DI MOVIMENTO NON SIA DI CANCELLAZIONE O DI RETTIFICA, IN TAL CASO LASCIO CORRERE)
		*/
		IF ISNULL(@Qta_Pezzi_Input,-1) < 0 AND @Id_Causale_Movimento NOT IN (5,6)
			THROW 50001, 'INSERITA QUANTITA ERRATA', 1

		IF ISNULL(@Qta_Persistenza_Nuova,0) < 0
			THROW 50001, 'SpEx_QtaPersNotNegative', 1

		--PRENDO LA QUANTITA' CONTENUTA NELLA CASSETTA E LA QUANTITA_PERSISTENZA
		SELECT	@Qta_Giacenza				= ISNULL(Quantita_Pezzi,0),
				@Qta_Persistenza_Giacenza	= ISNULL(Qta_Persistenza,0),
				@Id_Articolo				= ISNULL(Id_Articolo,0)
		FROM	Udc_Dettaglio
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio

		--Nel caso di constuntivazione l3 di prelievi manuali salvo l'id udc prima cheil trigger la elimini
		IF @Id_Causale_Movimento = 1 -- PIKING LISTA
		BEGIN
			--NON DEVE ANDARE IN ECCEZIONE IL VINCOLO CHECK ALTRIMENTI FA CASINI CON LE TRANSAZIONI DISTRIBUITE SU LINKED SERVER
			--https://stackoverflow.com/questions/546781/check-contraint-bypassing-catch-block-in-distributed-transaction
			--SE LA QUANTITA DA PRELEVARE E' MAGGIORE RISPETTO ALLA GIACENZA CONTENUTA NELLA CASSETTA ALLORA TIRO FUORI UN ECCEZIONE
			IF @Qta_Pezzi_Input > @Qta_Giacenza
			BEGIN
				DECLARE @MSG_ERR VARCHAR(MAX) = CONCAT('QUANTITA PEZZI INPUT ',@QTA_PEZZI_INPUT, ' MAGGIORE DELLA GIACENZA REGISTRATA ',@QTA_GIACENZA)
				;THROW 50009,@MSG_ERR, 1
			END

			DECLARE @Qta_Richiesta_Lista	numeric(10,2) = 0
			DECLARE @QuantitaGiaPrelevata	numeric(10,2) = 0
			DECLARE @Udm					varchar(3)
			DECLARE @Tipo_Prelievo			BIT
			
			SELECT	@Udm = Unita_Misura
			FROM	Articoli
			WHERE	Id_Articolo = @Id_Articolo

			--Stato 3 per modula parziale
			SELECT	@Qta_Richiesta_Lista = Quantita,
					@QuantitaGiaPrelevata = Qta_Prelevata,
					@Tipo_Prelievo = FL_MANCANTI
			FROM	Missioni_Picking_Dettaglio
			WHERE	Id_Udc = @Id_Udc
				AND Id_udcDettaglio = @Id_UdcDettaglio
				AND Id_Riga_Lista = @Id_Riga_Lista
				AND (
						Id_Stato_Missione IN (2,3)
						OR
						(Id_Stato_Missione = 5 AND EXISTS(SELECT TOP 1 1 FROM Udc_Testata WHERE Id_Udc = @Id_Udc and Id_Tipo_Udc IN ('I','M')))
					)

			IF @Id_UdcDettaglio IS NULL
				THROW 50001, 'ID UDC DETTAGLIO NON DEFINITA, PROVARE A REFRESHARE LA PAGINA', 1

			--SOLO DA MODULA MI PUO ARRIVARE QUANTITA 0 DA CONSUNTIVARE CON FL_VOID A 1
			IF @Id_Riga_Lista = 0 OR @Id_Testata_Lista = 0
				THROW 50012, 'ERRORE: RIGA O TESTATA LISTA DI PRELIEVO NON DEFINITI, RIPROVARE', 1

			--Posso prelevare una quantità maggiore solo in caso di UDM diverso da Metri
			IF	(@Qta_Pezzi_Input + @QuantitaGiaPrelevata) > @Qta_Richiesta_Lista
					AND
				@Udm NOT IN ('MT', 'KG', 'LT')
					AND
				@Id_Udc <> @ID_UDC_MODULA
			BEGIN
				DECLARE @MSG_ERROR_QTA VARCHAR(MAX) = CONCAT('PRELEVATA QUANTITA MAGGIORE RISPETTO ALLA QUANTITA RICHIESTA QTA GIA PREL: ',@QuantitaGiaPrelevata,
																' QTA RICHIESTA ', @Qta_Richiesta_Lista, ' QTA INPUT ', @Qta_Pezzi_Input, ' dettaglio ', @Id_UdcDettaglio)
				;THROW 50011, @MSG_ERROR_QTA,1
			END
			--Se è picking al metro o al kg lascio la possibilità di inserire un quantità maggiore, lascio la possibiilità di picking maggiore anche se proviene da Modula
			ELSE IF	(@Qta_Pezzi_Input + @QuantitaGiaPrelevata) > @Qta_Richiesta_Lista
						AND
					(@Udm IN ('MT', 'KG', 'LT') OR @Id_Udc = @ID_UDC_MODULA)
				UPDATE	Missioni_Picking_Dettaglio
				SET		Id_Stato_Missione = 4,
						Qta_Prelevata += @Qta_Pezzi_Input,
						DataOra_Evasione = GETDATE()
				WHERE	Id_Testata_Lista = @Id_Testata_Lista
					AND Id_udcDettaglio = @Id_UdcDettaglio
					AND Id_Riga_Lista = @Id_Riga_Lista

			--SE MI ARRIVA UNA QUANTITA MINORE DA MODULA E COMUNQUE CONCLUSA
			ELSE IF @Qta_Pezzi_Input = 0
						AND
					@Id_Udc = @ID_UDC_MODULA
						AND
					@Flag_FlVoid = 1
				UPDATE	Missioni_Picking_Dettaglio
				SET		Id_Stato_Missione = 4,
						DataOra_Evasione = GETDATE()
				WHERE	Id_Testata_Lista = @Id_Testata_Lista
					AND Id_udcDettaglio = @Id_UdcDettaglio
					AND Id_Riga_Lista = @Id_Riga_Lista

			--Parzialmente evasa per automha la lascio in stato 3
			ELSE IF (@Qta_Pezzi_Input + @QuantitaGiaPrelevata) < @Qta_Richiesta_Lista
				UPDATE	Missioni_Picking_Dettaglio
				SET		Id_Stato_Missione = 3,
						Qta_Prelevata += @Qta_Pezzi_Input,
						DataOra_Evasione = GETDATE()
				WHERE	Id_Testata_Lista = @Id_Testata_Lista
					AND Id_udcDettaglio = @Id_UdcDettaglio
					AND Id_Riga_Lista = @Id_Riga_Lista

			--Se corrisponde
			ELSE IF (@Qta_Pezzi_Input + @QuantitaGiaPrelevata) = @Qta_Richiesta_Lista
				UPDATE	Missioni_Picking_Dettaglio
				SET		Id_Stato_Missione = 4,
						Qta_Prelevata += @Qta_Pezzi_Input,
						DataOra_Evasione = GETDATE()
				WHERE	Id_Testata_Lista = @Id_Testata_Lista
					AND Id_udcDettaglio = @Id_UdcDettaglio
					AND Id_Riga_Lista = @Id_Riga_Lista

			--Aggiorno Udc dettaglio
			UPDATE	dbo.Udc_Dettaglio
			SET		Quantita_Pezzi = Quantita_Pezzi - @Qta_Pezzi_Input,
					Id_Tipo_Causale_Movimento = @Id_Causale_Movimento,
					Id_Testata_Lista_Prelievo = @Id_Testata_Lista,
					Id_Riga_Lista_Prelievo = @Id_Riga_Lista,
					Id_Utente_Movimento = @Id_Utente
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
				
			IF @Kitting = 0
			BEGIN
				--GENERO CONSUNTIVO VERSO L3
				IF ISNULL(@Tipo_Prelievo,0) = 0
					EXEC [dbo].[sp_Genera_Consuntivo_PrelievoLista]
								@Id_Udc = @Id_Udc,
								@Id_Testata_Lista = @Id_Testata_Lista,
								@Id_Riga_Lista = @Id_Riga_Lista,
								@Qta_Prelevata = @Qta_Pezzi_Input,
								@Fl_Void = @Flag_FlVoid,
								@USERNAME = @USERNAME,
								@Id_Processo = @Id_Processo,
								@Origine_Log = @Origine_Log,
								@Id_Utente = @Id_Utente,
								@Errore = @Errore OUTPUT
				ELSE
					EXEC sp_Genera_Consuntivo_Mancanti
						@Id_Testata		= @Id_Testata_Lista,
						@Id_Riga		= @Id_Riga_Lista,
						@Id_Articolo	= @Id_Articolo,
						@Qta_Prelievo	= @Qta_Pezzi_Input,
						@Id_Processo	= @Id_Processo,
						@Origine_Log	= @Origine_Log,
						@Id_Utente		= @Id_Utente,
						@Errore			= @Errore			OUTPUT

				IF ISNULL(@Errore, '') <> ''
					THROW 50100, @Errore, 1
			END

			--Controllo fine Lista
			EXEC [dbo].[sp_Update_Stati_ListePrelievo]
						@Id_Testata_Lista = @Id_Testata_Lista,
						@Id_Processo = @Id_Processo,
						@Origine_Log = @Origine_Log,
						@Id_Utente = @Id_Utente,
						@Errore = @Errore OUTPUT

			IF ISNULL(@Errore, '') <> ''
				THROW 50100, @Errore, 1
		END
		--SCORRO IL CAUSALE MOVIMENTO PASSATO IN INGRESSO PER CAPIRE CHE OPERAZIONE DEVO FARE
		ELSE IF @Id_Causale_Movimento = 2 -- PIKING MANUALE
		BEGIN
			--CONSUNTIVAZIONE L3 PER I MOVIMENTI MANUALE FATTI IN BAIA PICKING MANUALE O FATTI DA MODULA PER LISTE MANUALI E MOVIMENTA<ZIONI DI ARTICOLU
			IF ISNULL(@Id_Causale , '') <> ''
			BEGIN
				EXEC [dbo].[sp_Genera_Consuntivo_MovimentiMan]
							@IdCausaleL3			= @Id_Causale,
							@IdUdcDettaglio			= @Id_UdcDettaglio,
							@IdCausaleMovimento		= @Id_Causale_Movimento,
							@Flag_ControlloQualita	= @FlagControlloQualita, 
							@SUPPLIER_CODE			= @SUPPLIER_CODE,
							@REASON					= @REASON,
							@REF_NUMBER				= @REF_NUMBER,
							@DOC_NUMBER				= @DOC_NUMBER,
							@RETURN_DATE			= @RETURN_DATE,
							@USERNAME				= @USERNAME,
							@WBS_CODE				= @WBS_CODE,
							@CONTROL_LOT			= @CONTROL_LOT,
							@PROD_ORDER				= @PROD_ORDER,
							@NOTES					= @NOTES,
							@Quantity				= @Qta_Pezzi_Input, 
							@Id_Processo			= @Id_Processo,
							@Origine_Log			= @Origine_Log,
							@Id_Utente				= @Id_Utente,
							@Errore					= @Errore OUTPUT

				IF ISNULL(@Errore, '') <> ''
					THROW 50001, @Errore, 1
			END

			IF @FlagControlloQualita = 1
				THROW 50100, 'IMPOSSIBILE PRELEVARE UN ARTICOLO SOGGETTO A CONTROLLO QUALITA''',1
				
			IF @FlagNonConforme = 1
				THROW 50100, 'IMPOSSIBILE PRELEVARE UN ARTICOLO SOGGETTO A NON CONFORMITA''',1
				
			--SE LA QUANTITA DA PRELEVARE E' MAGGIORE RISPETTO ALLA GIACENZA CONTENUTA NELLA CASSETTA ALLORA TIRO FUORI UN ECCEZIONE
			IF	@Qta_Pezzi_Input > @Qta_Giacenza
				THROW 50001, 'SpEx_QtaGiacenzaNotEnough', 1
			ELSE
				--SENNO' FACCIO L'UPDATE NELLA UDC_DETTAGLIO SOTTRAENDO LA QUANTITA RICHIESTA DALLA GIACENZA ATTUALE
				--Salvo riga e testata nel caso sia un picking di mancanti
				UPDATE	dbo.Udc_Dettaglio
				SET		Quantita_Pezzi = Quantita_Pezzi - @Qta_Pezzi_Input,
						Id_Tipo_Causale_Movimento = @Id_Causale_Movimento,
						Id_Causale_L3 = @Id_Causale,
						Id_Testata_Lista_Prelievo = @Id_Testata_Lista,
						Id_Riga_Lista_Prelievo = @Id_Riga_Lista,
						Id_Utente_Movimento = @Id_Utente
				WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
		END
		ELSE IF @Id_Causale_Movimento IN (3,7) -- CARICO MANUALE O CARICO LISTA
		BEGIN
			IF ISNULL(@Id_UdcDettaglio, 0) <> 0
			BEGIN
				--SE LA SOMMA TRA LA GIACENZA E LA QUANTITA' DA INSERIRE SUPERA LA QTA_PERSISTENZA FACCIO PARTIRE UN ECCEZIONE (A MENO CHE LA QTA_PERSISTENZA_GIACENZA SIA UGUALE A 0,
				--IN TAL CASO LASCIO PASSARE TUTTO)
				IF	@Qta_Persistenza_Giacenza <> 0
						AND
					(@Qta_Pezzi_Input + @Qta_Giacenza) > @Qta_Persistenza_Giacenza
					THROW 50001, 'SpEx_QtaInsertedTooMuch', 1
				ELSE
				BEGIN
					--SE TUTTO VA BENE ESEGUO L'UPDATE DELLA UDC_DETTAGLIO SOMMANDO LA GIACENZA ATTUALE CON LA QUANTITA' DA INSERIRE
					UPDATE	dbo.Udc_Dettaglio
					SET		Quantita_Pezzi				= Quantita_Pezzi + @Qta_Pezzi_Input,
							Id_Tipo_Causale_Movimento	= @Id_Causale_Movimento,
							--Importante riassegare il valore di testata e riga uguale al precedente
							Id_Ddt_Reale				= ISNULL(@Id_Ddt_Reale,Id_Ddt_Reale),
							Id_Riga_Ddt					= ISNULL(@Id_Riga_Ddt,Id_Riga_Ddt),
							Id_Causale_L3				= @Id_Causale,
							Id_Utente_Movimento			= @Id_Utente
					WHERE	Id_UdcDettaglio = @Id_UdcDettaglio

					--AGGIUNTA FLAG CONTROLLO QUALITA DA SPECIALIZZAZIONE
					IF @FlagControlloQualita = 1
					BEGIN
						--Se esiste già una quantita di quell articolo flaggata in cq aggiungo la quantita' che sto passando adesso
						IF	EXISTS	(
										SELECT	TOP 1 1
										FROM	Custom.ControlloQualita
										WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
											AND ISNULL(CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,'')
									)
							UPDATE	Custom.ControlloQualita
							SET		Quantita = Quantita + @Qta_Pezzi_Input,
									MotivoQualita = ISNULL(@Motivo_CQ,MotivoQualita),
									Doppio_Step_QM = @DOPPIO_STEP_QM,
									Id_Utente = ISNULL(@USERNAME, @Id_Utente)
							WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
								AND ISNULL(CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,'')
						ELSE
							INSERT INTO Custom.ControlloQualita
								(Id_UdcDettaglio,Quantita, MotivoQualita,Doppio_Step_QM,CONTROL_LOT, Id_Utente)
							VALUES
								(@Id_UdcDettaglio, @Qta_Pezzi_Input , @Motivo_CQ, @DOPPIO_STEP_QM,ISNULL(@CONTROL_LOT,''), ISNULL(@USERNAME, @Id_Utente))

						IF (ISNULL(@Errore, '') <> '')
							RAISERROR(@Errore, 12, 1)
					END

					IF @FlagNonConforme = 1
					BEGIN
						--Se esiste già una quantita di quell articolo flaggata in cq aggiungo la quantita' che sto passando adesso
						IF	EXISTS	(
										SELECT	TOP 1 1
										FROM	Custom.NonConformita
										WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
											AND ISNULL(CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,'')
									)
							UPDATE	Custom.NonConformita
							SET		Quantita = Quantita + @Qta_Pezzi_Input,
									MotivoNonConformita= ISNULL(@Motivo_NC,MotivoNonConformita)
							WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
								AND ISNULL(CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,'')
						ELSE
							INSERT INTO Custom.NonConformita
								(Id_UdcDettaglio,Quantita, MotivoNonConformita,CONTROL_LOT)
							VALUES
								(@Id_UdcDettaglio, @Qta_Pezzi_Input, @Motivo_NC, ISNULL(@CONTROL_LOT,''))

						IF (ISNULL(@Errore, '') <> '')
							RAISERROR(@Errore, 12, 1)
					END
				END
			END
			ELSE
			BEGIN
				--SE NON C'E' NESSUNA GIACENZA PRESENTE PROCEDO CON UN NUOVO INSERIMENTO NELLA UDC_DETTAGLIO
				--CONTROLLO SE LA QTA_PERSISTENZA PASSATA IN INPUT NON SIA NULL
				SET @Matricola = ' '
				SET @Lotto = ' '
				
				--SE NON HO RISCONTRATO ERRORI PROCEDO CON L'INSERT NELLA UDC_DETTAGLIO
				INSERT INTO dbo.Udc_Dettaglio
					(Id_Udc,Id_Articolo,Matricola,Data_Creazione,Data_Lotto,Data_Scadenza,Lotto,Id_Utente_Movimento,Id_Tipo_Causale_Movimento,Id_Lista,Id_Dettaglio,
					Quantita_Pezzi,Id_Contenitore,Posizione_X,Posizione_Y,Qta_Persistenza,Note,Xml_Param,Id_UdcContainer, Id_Ddt_Reale, Id_Riga_Ddt, Id_Causale_L3,WBS_Riferimento, Control_Lot)
				VALUES
					(@Id_Udc,@Id_Articolo,@Matricola,ISNULL(@Data_Creazione,GETDATE()),NULL,@Data_Scadenza,@Lotto,@Id_Utente,@Id_Causale_Movimento,
					@Id_Lista,@Id_Dettaglio,@Qta_Pezzi_Input,NULL,0,0,@Qta_Persistenza_Nuova,NULL,NULL,@Id_UdcContainer,  @Id_Ddt_Reale, @Id_Riga_Ddt, @Id_Causale, UPPER(@WBS_CODE),NULL)
					
				--LO SELEZIONO MANUALMENTE RISPETTO A QUANTO STO PASSANDO
				SELECT	@Id_UdcDettaglio = Id_UdcDettaglio
				FROM	Udc_Dettaglio
				WHERE	Id_Udc = @Id_Udc
					AND Id_Articolo = @Id_Articolo
					AND ISNULL(WBS_Riferimento,'') = ISNULL(@WBS_CODE,'')

				IF @CONTROL_LOT IN ('000000000000','.','') 
					SET @CONTROL_LOT = ''

				IF @FlagControlloQualita = 1
				BEGIN
					--INSERISCO IN CONTROLLO QUALITA
					INSERT INTO Custom.ControlloQualita
						(Id_UdcDettaglio,Quantita, MotivoQualita,Doppio_Step_QM,CONTROL_LOT,Id_Utente)
					VALUES
						(@Id_UdcDettaglio, @Qta_Pezzi_Input, @Motivo_CQ,@DOPPIO_STEP_QM, ISNULL(@CONTROL_LOT,''), ISNULL(@USERNAME, @Id_Utente))
				END

				IF @FlagNonConforme = 1
				BEGIN
					--INSERISCO IN CONTROLLO QUALITA
					INSERT INTO Custom.NonConformita
						(Id_UdcDettaglio,Quantita, MotivoNonConformita,CONTROL_LOT)
					VALUES
						(@Id_UdcDettaglio, @Qta_Pezzi_Input, @Motivo_NC, ISNULL(@CONTROL_LOT,''))
				END
			END
			
			--GENERO IL CONSUNTIVO DI ENTRATA MERCE SE E UN CARICO DA LISTA NON SU UDC FITTIZIA
			IF	@Id_Causale_Movimento = 7
					AND
				EXISTS	(
							SELECT	TOP 1 1
							FROM	Udc_Posizione
							WHERE	Id_Udc = @Id_Udc
								AND Id_Partizione NOT IN (9104, 9105, 9106) --> AREE A TERRA DELLE BAIE DI SPECIALIZZAZIONE
						)
			BEGIN
				IF ISNULL(@Invio_Consuntivo,1) = 1
				BEGIN
					--INVIO CONSUNTIVO L3
					EXEC [dbo].[sp_Genera_Consuntivo_EntrataLista]
								@Id_Udc				= @Id_Udc,
								@Id_Testata_Ddt		= @Id_Ddt_Reale,
								@Id_Riga_Ddt		= @Id_Riga_Ddt,
								@Qta_Entrata		= @Qta_Pezzi_Input,
								@Fl_Quality_Check	= @FlagControlloQualita,
								@Doppio_Step_QM		= @DOPPIO_STEP_QM,
								@Fl_Void			= @Flag_FlVoid,
								@USERNAME			= NULL,
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Id_Utente			= @Id_Utente,
								@Errore				= @Errore			OUTPUT

					IF ISNULL(@Errore, '') <> ''
						THROW 50006, @Errore, 1
				END
			END

			--SE SONO IN 2STEP QM ALLORA VADO IN CONTROLLO QUALITA'
			IF	@DOPPIO_STEP_QM = 1 AND ISNULL(@FlagControlloQualita,0)=0
			BEGIN
				IF @CONTROL_LOT IN ('000000000000','.','') 
					SET @CONTROL_LOT = ''

				IF EXISTS	(
								SELECT	TOP 1 1
								FROM	Custom.ControlloQualita
								WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
									AND ISNULL(CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,'')
							)
						UPDATE	Custom.ControlloQualita
						SET		Quantita		= Quantita + @Qta_Pezzi_Input,
								MotivoQualita	= ISNULL(@Motivo_CQ,MotivoQualita),
								Doppio_Step_QM	= @DOPPIO_STEP_QM,
								Id_Utente		= ISNULL(@USERNAME, @Id_Utente)
						WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
							AND ISNULL(CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,'')
				ELSE
					INSERT INTO Custom.ControlloQualita
						(Id_UdcDettaglio,Quantita, MotivoQualita,Doppio_Step_QM, CONTROL_LOT, Id_Utente)
					VALUES
						(@Id_UdcDettaglio, @Qta_Pezzi_Input , '2 STEP QM',@DOPPIO_STEP_QM, ISNULL(@CONTROL_LOT,''),ISNULL(@USERNAME, @Id_Utente))
			END
		END
		ELSE IF @Id_Causale_Movimento = 5 -- RETTIFICA SALDO
		BEGIN
			-- SE LA QUANTITA' DA RETTIFICARE SUPERA LA PERSISTENZA ALLORA TIRA FUORI ERRORE
			IF	@Qta_Persistenza_Giacenza <> 0
					AND
				@Qta_Pezzi_Input > @Qta_Persistenza_Giacenza
				THROW 50001, 'SpEx_QtaInsertedTooMuch', 1

			IF @FlagControlloQualita = 1
				THROW 50100, 'IMPOSSIBILE RETTIFICARE UNA QUANTITA'' SOGGETTA A CONTROLLO QUALITA''',1

			-- PER LA RETTIFICA FACCIO UN SEMPLICE UPDATE DELLA QUANTITA E DELL'ID_CAUSALE_MOVIMENTO
			UPDATE	dbo.Udc_Dettaglio
			SET		Quantita_Pezzi = @Qta_Pezzi_Input,
					Id_Tipo_Causale_Movimento = @Id_Causale_Movimento,
					Id_Utente_Movimento = @Id_Utente
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
		END

		ELSE IF @Id_Causale_Movimento = 6 -- CANCELLAZIONE
		BEGIN
			IF @FlagControlloQualita = 1
				THROW 50101, 'IMPOSSIBILE ELIMINARE UN ARTICOLO SOGGETTO A CONTROLLO QUALITA''',1

			--PER LA CANCELLAZIONE AGGIORNO L'ID_UTENTE_MOVIMENTO DI CHI HA ESEGUITO LA PROCEDURA E SECCO LA RIGA DELL'UDC_DETTAGLIO CON UNA QUERY DI DELETE
			UPDATE	Udc_Dettaglio
			SET		Id_Utente_Movimento = @Id_Utente
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio

			DELETE	Custom.ControlloQualita
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
			
			DELETE	Custom.NonConformita
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
			
			DELETE	dbo.Udc_Dettaglio
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
		END
		ELSE
			THROW 50001, 'SpEx_CausaleMovimentoNotHandled', 1

		--CONSUNTIVAZIONE L3 PER I MOVIMENTI MANUALE FATTI IN BAIA PICKING MANUALE O FATTI DA MODULA PER LISTE MANUALI E MOVIMENTA<ZIONI DI ARTICOLU
		IF	ISNULL(@Id_Causale, '') NOT IN ('','CWBS','DWBS','NWBS')
				AND
			@Id_Causale_Movimento = 3
		BEGIN
			EXEC [dbo].[sp_Genera_Consuntivo_MovimentiMan]
						@IdCausaleL3 = @Id_Causale,
						@IdUdcDettaglio = @Id_UdcDettaglio,
						@IdCausaleMovimento = @Id_Causale_Movimento,
						@Flag_ControlloQualita = @FlagControlloQualita, 
						@SUPPLIER_CODE = @SUPPLIER_CODE,
						@REASON = @REASON ,
						@REF_NUMBER = @REF_NUMBER,
						@DOC_NUMBER = @DOC_NUMBER,
						@RETURN_DATE = @RETURN_DATE,
						@USERNAME = @USERNAME,
						@WBS_CODE = @WBS_CODE,
						@CONTROL_LOT = @CONTROL_LOT,
						@PROD_ORDER = @PROD_ORDER,
						@NOTES = @NOTES,
						@Quantity = @Qta_Pezzi_Input, 
						@Id_Processo = @Id_Processo,
						@Origine_Log = @Origine_Log,
						@Id_Utente = @Id_Utente,
						@Errore = @Errore OUTPUT

			IF (ISNULL(@Errore, '') <> '')
				THROW 50001, @Errore, 1
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
