SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE  PROC [dbo].[sp_Crea_Missioni_Modula_NoSap]
	--dati sorgente
	@Id_Udc					INT,
	@Id_Udc_Dettaglio		INT				= NULL,
	@Id_Evento				INT				= NULL,
	@Codice_Articolo		VARCHAR(MAX),

	-- IN CASO DI SPECIALIZZAZIONE QUESTA CORRISPONDE ALLA QTA ANCORA DA SPECIALIZZARE
	@Quantita_Pezzi			NUMERIC(10,4),
	@FLAG_CONTROLLO_QUALITA BIT = 0,
	@Flag_Non_Conformita	BIT = 0,

	--quantita da spostare
	@Quantita_Articolo		NUMERIC(10,4),

	--dati in caso di specializzazione
	@Id_Testata				INT				= NULL,
	@NUMERO_RIGA			INT				= NULL,

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
		DECLARE @ID_ARTICOLO						INT
		DECLARE @Id_Partizione_Attuale				INT
		DECLARE @Id_Area_Terra_Adiacente			INT
		DECLARE @Id_Tipo_Partizione_Attuale			VARCHAR(2)
		
		--UDC DESTINAZIONE
		DECLARE @Id_NuovaUdc_Dettaglio				INT = NULL
		DECLARE @Id_Nuova_Udc_Terra					INT = 0
		
		IF (@Id_Udc_Dettaglio IS NULL AND @Id_Testata IS NULL)
			THROW 50003, 'MANCANZA DI DATI NECESSARI ALLO SPOSTAMENTO', 1

		--SE HO IL DETTAGLIO COMANDA QUELLO
		IF (@Id_Udc_Dettaglio IS NOT NULL)
			SET @Id_Testata = NULL

		IF @FLAG_CONTROLLO_QUALITA = 1
			THROW 50003, 'IMPOSSIBILE MOVIMENTARE VERSO MODULA UNA QUANTITA SOGGETTA A CONTROLLO QUALITA O A DOPPIO STEP QM', 1

		IF @Flag_Non_Conformita = 1
			THROW 50003, 'IMPOSSIBILE MOVIMENTARE VERSO MODULA UNA QUANTITA SOGGETTA A NON CONFORMITA', 1

		IF @ID_ARTICOLO IS NULL
			SELECT	@Id_Articolo = Id_Articolo
			FROM	dbo.Articoli
			WHERE	Codice = @Codice_Articolo

		SELECT	@Id_Partizione_Attuale = UP.Id_Partizione,
				@Id_Tipo_Partizione_Attuale = P.ID_TIPO_PARTIZIONE
		FROM	dbo.Udc_Posizione	UP
		JOIN	dbo.Partizioni		P
		ON		P.ID_PARTIZIONE = UP.Id_Partizione
		WHERE	UP.Id_Udc = @Id_Udc

		--Se la quantità rilevata di un articolo è maggiore de 
		IF @Quantita_Articolo > @Quantita_Pezzi
			THROW 50010, 'QUANTITA INSERITA IN ECCESSO RISPETTO A QUELLA DICHIARATA NEL DDT',1

		IF @Quantita_Articolo <= 0
			THROW 50001, 'IMPOSSIBILE MOVIMENTARE IN MODULA QUANTITA MINORI O UGUALI A 0',1
			
		SET @Id_Area_Terra_Adiacente = CASE
											WHEN @Id_Tipo_Partizione_Attuale = 'AT' THEN @Id_Partizione_Attuale
											WHEN @Id_Partizione_Attuale = 3301 THEN 9104
											WHEN @Id_Partizione_Attuale = 3302 THEN 9105
											WHEN @Id_Partizione_Attuale = 3203 THEN 9104
											WHEN @Id_Partizione_Attuale = 3501 THEN 9106
											ELSE 9104
										END

		IF @Id_Area_Terra_Adiacente = 0
			THROW 50006, 'NESSUNA AREA A TERRA TROVATA',1

		--Creo L'Udc
		EXEC dbo.sp_Insert_Crea_Udc
				@Id_Tipo_Udc	= '1',
				@Id_Partizione	= @Id_Area_Terra_Adiacente,
				@Id_Udc			= @Id_Nuova_Udc_Terra		OUTPUT,
				@Id_Processo	= @Id_Processo,
				@Origine_Log	= @Origine_Log,
				@Id_Utente		= @Id_Utente,
				@Errore			= @Errore					OUTPUT

		IF @Id_Nuova_Udc_Terra = 0
			THROW 50007, 'IMPOSSIBILE CREARE NUOVA UDC IN AREA A TERRA', 1;

		IF @Id_Evento IS NOT NULL AND @Id_Testata IS NOT NULL
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

		--SE NON SONO IN FASE DI SPECIALIZZAZIONE Rimuovo dalla UDC corrente
		IF @Id_Udc_Dettaglio IS NOT NULL
			EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
						@Id_UdcDettaglio		= @Id_Udc_Dettaglio,
						@Qta_Pezzi_Input		= @Quantita_Articolo,
						@Id_Causale_Movimento	= 2,
						@Id_Processo			= @Id_Processo,
						@Origine_Log			= @Origine_Log,
						@Id_Utente				= @Id_Utente,
						@Errore					= @Errore OUTPUT

		--Aggiungo l'articolo alla nuova Udc aggiornando
		EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
				@Id_Udc					= @Id_Nuova_Udc_Terra,
				@Id_Articolo			= @Id_Articolo,
				@Id_UdcDettaglio		= @Id_NuovaUdc_Dettaglio,
				@Qta_Pezzi_Input		= @Quantita_Articolo,
				@Id_Causale_Movimento	= 7,
				@Id_Ddt_Reale			= @Id_Testata,
				@Id_Riga_Ddt			= @NUMERO_RIGA,
				@Invio_Consuntivo		= 0,
				@Id_Processo			= @Id_Processo,
				@Origine_Log			= @Origine_Log,
				@Id_Utente				= @Id_Utente,
				@Errore					= @Errore		OUTPUT

		EXEC [dbo].[sp_Invia_Ordine_Entrata_Modula_NoSap]
					@Id_Udc				= @Id_Nuova_Udc_Terra,
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Id_Utente			= @Id_Utente,
					@Errore				= @Errore			OUTPUT
					
		IF (ISNULL(@Errore, '') <> '')
			RAISERROR (@Errore, 12, 1)
		
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
