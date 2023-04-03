SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Rimuovi_Qta_Articolo]
	@Id_UdcDettaglio		INT,
	@Qta_Pezzi_Input		NUMERIC(10,2),
	@Id_Causale_Movimento	INT,
	@Id_Causale				VARCHAR(5) = NULL,
	@FlagControlloQualita	BIT,
	@FlagNonConformita		BIT,
	--MOVIMENTAZIONE MANUALE CAMPI L3
	@Id_Magazzino			VARCHAR(5)		= NULL,
	@NOTES					VARCHAR(150)	= NULL,
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
		DECLARE	@Id_Udc			INT
		DECLARE	@Id_Articolo	INT
		DECLARE @WBS_CODE		VARCHAR(24)
		DECLARE @REF_NUMBER		VARCHAR(500)

		SELECT	@Id_Articolo = Id_Articolo,
				@Id_Udc = Id_Udc,
				@WBS_CODE = WBS_Riferimento
		FROM	Udc_Dettaglio
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
		
		IF ISNULL(@Qta_Pezzi_Input,0) = 0
			THROW 50001, 'NON HAI SPECIFICATO LA QUANTITA', 1

		IF @Id_Udc = 702
			THROW 50001, 'OPERAZIONE NON ESEGUIBILE SU MODULA DA AWM', 1

		IF @FlagControlloQualita = 1
			THROW 50001, 'IMPOSSIBILE PRELEVARE UNA QUANTITA SE L''ARTICOLO E SOGGETTO A CONTROLLO QUALITA',1

		--PRELIEVO DELL ARTICOLO NON CONFORME
		IF @FlagNonConformita = 1
			THROW 50001, 'IMPOSSIBILE PRELEVARE UNA QUANTITA SE L''ARTICOLO NON E CONFORME',1

		IF ISNULL(@Id_Causale, '') <> ''
		BEGIN
			DECLARE @Action			VARCHAR(1)
			SELECT	@Action = ISNULL(Action, '')
			FROM	Custom.CausaliMovimentazione
			WHERE	Id_Causale = @Id_Causale

			IF (@Action = '+' OR @Action = '')
				THROW 50001, ' HAI SELEZIONATO UNA CAUSALE DI CARICO MERCE, MENTRE STAI EFFETTUANDO UN PRELIEVO MANUALE', 1;

			IF (@Id_Causale = 'UMI' AND (ISNULL(@Id_Magazzino, '') = ''))
				THROW 50002, ' OBBLIGATORIO IL CAMPO NUMERO RIFERIMENTO CON CODICE MAGAZZINO PER CAUSALE UMI',1
		END

		IF @Id_Causale = 'UMI'
			SET @REF_NUMBER = @Id_Magazzino

		EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
				@Id_UdcDettaglio		= @Id_UdcDettaglio,
				@Qta_Pezzi_Input		= @Qta_Pezzi_Input,
				@Id_Causale_Movimento	= @Id_Causale_Movimento,
				@Id_Causale				= @Id_Causale,
				@Id_Processo			= @Id_Processo,
				@REF_NUMBER				= @REF_NUMBER,
				--@SUPPLIER_CODE			= @SUPPLIER_CODE,
				--@REASON					= @REASON,
				--@DOC_NUMBER				= @DOC_NUMBER,
				--@RETURN_DATE			= @RETURN_DATE,
				@WBS_CODE				= @WBS_CODE,
				@NOTES					= @NOTES,
				@Origine_Log			= @Origine_Log,
				@Id_Utente				= @Id_Utente,
				@Errore					= @Errore				OUTPUT

		IF (ISNULL(@Errore, '') <> '')
			THROW 50004, @Errore,1;

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
