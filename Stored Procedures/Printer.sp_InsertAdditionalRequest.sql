SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





CREATE PROCEDURE [Printer].[sp_InsertAdditionalRequest]
	@Id_Evento			INT				= NULL,
	@Id_Articolo		INT,
	@Quantita_Articolo	NUMERIC(18,4),
	@Id_Testata			INT,
	@Id_Riga			INT,
	-- Parametri Standard;
	@Id_Processo		VARCHAR(30),
	@Origine_Log		VARCHAR(25),
	@Id_Utente			VARCHAR(16),
	@Errore				VARCHAR(500) OUTPUT
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
		DECLARE @CODICE_ARTICOLO		VARCHAR(50)
		DECLARE @DESCRIZIONE_ARTICOLO	VARCHAR(50)

		DECLARE @CODICE_ORDINE_ACQUISTO VARCHAR(40)
		DECLARE @CONTROL_LOT			VARCHAR(40)

		SELECT	@CODICE_ARTICOLO = Codice,
				@DESCRIZIONE_ARTICOLO = Descrizione
		FROM	Articoli
		WHERE	Id_Articolo = @Id_Articolo

		SELECT	@CONTROL_LOT = CONTROL_LOT,
				@CODICE_ORDINE_ACQUISTO = PURCHASE_ORDER_ID
		FROM	Custom.RigheOrdiniEntrata
		WHERE	Id_Testata = @Id_Testata
			AND LOAD_LINE_ID = @Id_Riga

		EXEC Printer.sp_AddPrinterRequest
				@Id_Evento				= @Id_Evento,
				@TemplateName			= 'etichettaSpecializzazioneAdd',
				@CODICE_ARTICOLO		= @CODICE_ARTICOLO,
				@DESCRIZIONE_ARTICOLO	= @DESCRIZIONE_ARTICOLO,
				@Quantita_etichetta		= @Quantita_Articolo,
				@CONTROL_LOT			= @CONTROL_LOT,
				@CODICE_ORDINE_ACQUISTO	= @CODICE_ORDINE_ACQUISTO,
				@Id_Processo			= @Id_Processo,
				@Id_Utente				= @Id_Utente,
				@Origine_Log			= @Origine_Log,
				@Errore					= @Errore			OUTPUT
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
