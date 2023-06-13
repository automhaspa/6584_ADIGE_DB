SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Associa_Riga_UdcDettaglio]
	@Id_Udc						INT,
	@Id_Evento					INT,
	--Corrisponde al Id_Ddt_Reale presente in Eventi che corrisponde al DDT reale della specializzazione
	@Id_Testata					INT,
	@NUMERO_RIGA				INT,
	@Id_Articolo				INT,
	@CONTROLLO_QUALITA			BIT				= 0,
	@Quantita_Articolo			NUMERIC(10,4),
	@Motivo_Controllo_Qualita	varchar(MAX)	= NULL,
	-- Parametri Standard;
	@Id_Processo				VARCHAR(30),
	@Origine_Log				VARCHAR(25),
	@Id_Utente					VARCHAR(32),
	@Errore						VARCHAR(500) OUTPUT
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
		--Controllo le quantità inserito del articolo
		DECLARE @QuantitaRimanenteArticolo	NUMERIC(10,4) = -1
		DECLARE @IdUDcDettaglio				INT = NULL
		DECLARE @Ingombrante				BIT
		DECLARE @IdTipoUdc					VARCHAR(1)

		--CONTROLLO SE E' SPECIALIZZAZIONE DA BAIA O DA INGOMBRANTE IN BASE AL TIPO UDC
		SELECT  @Ingombrante =  CASE
									WHEN Id_Tipo_Udc IN ('I','M') THEN 1
									ELSE 0
								END
		FROM	dbo.Udc_Testata
		WHERE	Id_Udc = @Id_Udc

		IF @Quantita_Articolo = 0
			THROW 50001, 'IMPOSSIBILE SPECIALIZZARE QUANTITA A 0',1;

		SELECT	@QuantitaRimanenteArticolo =  ISNULL(QUANTITA_RIMANENTE_DA_SPECIALIZZARE, -1)
		FROM	AwmConfig.vQtaRimanentiRigheDdt
		WHERE	ID_RIGA = @NUMERO_RIGA
			AND Id_Testata = @Id_Testata

		IF @QuantitaRimanenteArticolo <= 0
			THROW 50001, 'QUANTITA'' RIMANENTE NON TROVATA PER LA RIGA IN QUESTIONE',1;

		--Se la quantità rilevata di un articolo è maggiore de
		IF @Quantita_Articolo > @QuantitaRimanenteArticolo
			THROW 50010, 'QUANTITA INSERITA IN ECCESSO RISPETTO A QUELLA DICHIARATA NEL DDT',1

		DECLARE @CONTROL_LOT		VARCHAR(40)
		DECLARE @DOPPIO_STEP_QM		BIT
		DECLARE @WBS_Riferimento	VARCHAR(40)

		SELECT	@CONTROL_LOT = CONTROL_LOT,
				@DOPPIO_STEP_QM = FL_QUALITY_CHECK,
				@WBS_Riferimento = WBS_ELEM
		FROM	Custom.RigheOrdiniEntrata
		WHERE	Id_Testata = @Id_Testata
			AND LOAD_LINE_ID = @NUMERO_RIGA

		--Se l'operatore sta specializzando lo un codice articolo già presente nell'UDC dettaglio procedo con quello
		SELECT	@IdUdcDettaglio = Id_UdcDettaglio
		FROM	dbo.Udc_Dettaglio
		WHERE	Id_Udc = @Id_Udc
			AND Id_Articolo = @Id_Articolo
			AND ISNULL(WBS_Riferimento,'') = ISNULL(@WBS_RIFERIMENTO,'')

		--Altrimenti aggiorno quantità
		EXEC [dbo].[sp_Update_Aggiorna_Contenuto_Udc]
				@Id_Udc					= @Id_Udc,
				@Id_UdcDettaglio		= @IdUDcDettaglio,
				@Id_Articolo			= @Id_Articolo,
				@Qta_Pezzi_Input		= @Quantita_Articolo,
				@Id_Causale_Movimento	= 7,
				@Flag_FlVoid			= 0,
				@FlagControlloQualita	= @CONTROLLO_QUALITA,
				@Motivo_CQ				= @Motivo_Controllo_Qualita,
				@Id_Ddt_Reale			= @Id_Testata,
				@Id_Riga_Ddt			= @NUMERO_RIGA,
				@WBS_CODE				= @WBS_Riferimento,
				@CONTROL_LOT			= @CONTROL_LOT,
				@DOPPIO_STEP_QM			= @DOPPIO_STEP_QM,
				@Id_Processo			= @Id_Processo,
				@Origine_Log			= @Origine_Log,
				@Id_Utente				= @Id_Utente,
				@Errore					= @Errore			OUTPUT

		--Se non ho errori nella creazione dell'udc_dettaglio
		IF (ISNULL(@Errore, '') <> '')
			THROW 50006, @Errore, 1

		--stampo la quantita aggiunta
		EXEC [Printer].[sp_InsertAdditionalRequest]
				@Id_Evento			= @Id_Evento,
				@Id_Articolo		= @Id_Articolo,
				@Quantita_Articolo	= @Quantita_Articolo,
				@Id_Testata			= @Id_Testata,
				@Id_Riga			= @NUMERO_RIGA,
				@Id_Processo		= @Id_Processo,
				@Id_Utente			= @Id_Utente,
				@Origine_Log		= @Origine_Log,
				@Errore				= @Errore			OUTPUT

		--CONTROLLO LO STATO DEL DDT
		EXEC [dbo].[sp_Update_Stati_OrdiniEntrata]
				@Id_Evento			= @Id_Evento,
				@Id_Riga			= @NUMERO_RIGA,
				@Id_Testata			= @Id_Testata,
				@SpecIngombranti	= @Ingombrante,
				--Se son qui non ho nessun annullamento lista
				@FlagChiusura		= 0,
				@Id_Processo		= @Id_Processo,
				@Origine_Log		= @Origine_Log,
				@Id_Utente			= @Id_Utente,
				@Errore				= @Errore OUTPUT

		IF ISNULL(@Errore, '') <> ''
			THROW 50006, @Errore, 1

		--GESTIONE MANCANTI --Se la quantita specializzata è conforme
		IF	@CONTROLLO_QUALITA = 0
				AND
			@DOPPIO_STEP_QM = 0
		BEGIN
			IF EXISTS	(
							SELECT	TOP(1) 1
							FROM	Custom.AnagraficaMancanti
							WHERE	Id_Articolo = @Id_Articolo
								AND Qta_Mancante > 0
								AND ISNULL(WBS_Riferimento,'') = ISNULL(@WBS_Riferimento,'')
						)
			BEGIN
				DECLARE @Id_Partizione_Destinazione			INT = 0

				SELECT	@Id_Partizione_Destinazione = ID_Partizione
				FROM	Eventi
				WHERE	Id_Evento = @Id_Evento

				IF ISNULL(@Id_Partizione_Destinazione, 0) = 0
					SELECT	@Id_Partizione_Destinazione = Id_Partizione
					FROM	Udc_Posizione
					WHERE	Id_Udc = @Id_Udc

				DECLARE @XmlParam xml = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc><Id_Articolo>',@Id_Articolo,'</Id_Articolo><Missione_Modula>',0,'</Missione_Modula></Parametri>')

				EXEC @Return = sp_Insert_Eventi
						@Id_Tipo_Evento		= 36,
						@Id_Partizione		= @Id_Partizione_Destinazione,
						@Id_Tipo_Messaggio	= 1100,
						@XmlMessage			= @XmlParam,
						@id_evento_padre	= @Id_Evento,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore OUTPUT;

				IF @Return <> 0 RAISERROR(@Errore,12,1);
			END
		 END

		--Fine del codice;		
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
