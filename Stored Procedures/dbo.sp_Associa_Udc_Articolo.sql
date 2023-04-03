SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Associa_Udc_Articolo]
	@Id_Articolo	INT = NULL,
	@Id_Udc			INT,
	@Quantita		INT = NULL,
	@Id_Evento		INT,
	@Fine_Articoli	BIT = 1,
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
	SET @Nome_StoredProcedure = Object_Name(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		-- Inserimento del codice;
		DECLARE @Id_Partizione_Destinazione INT
		DECLARE @Id_Partizione				INT
		DECLARE @Id_Tipo_Messaggio			INT
		DECLARE	@ID_MISSIONE				INT
		
		IF	@Id_Articolo IS NOT NULL
				AND 
			@Quantita IS NULL
			THROW 50005, 'NECESSARIO SPECIFICARE QUANTITA SE UN CODICE ARTICOLO E SELEZIONATO', 1
		
		IF	@Id_Articolo IS NOT NULL
				AND
			@Quantita IS NOT NULL
			BEGIN
				IF @Quantita < 1
					THROW 50006, 'QUANTITA IMMESSA NON VALIDA', 1

				--Aggiorno Udc Dettaglio
				EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
							@Id_Udc					= @Id_Udc,
							@Id_UdcDettaglio		= NULL,
							@Id_Articolo			= @Id_Articolo,
							@Qta_Pezzi_Input		= @Quantita,
							@Id_Causale_Movimento	= 3,
							@Id_Processo			= @Id_Processo,
							@Origine_Log			= @Origine_Log,
							@Id_Utente				= @Id_Utente,
							@Errore					= @Errore		OUTPUT
			END

		--Se ho finito di censire gli articoli
		IF @Fine_Articoli = 1
		BEGIN
			--LANCIO LA MISSIONE DI INBOUND 		
			SELECT	@Id_Partizione = Id_Partizione
			FROM	Udc_Testata		ut
			JOIN	Udc_Posizione	up
			ON		ut.Id_Udc = up.Id_Udc
			WHERE	ut.Id_UDc = @Id_Udc

			--SONO ANCORA NELLA SEZIONE LU_ON_ASI
			SELECT	@Id_Partizione_Destinazione = Id_Partizione_OK
			FROM	dbo.Procedure_Personalizzate_Gestione_Messaggi
			WHERE	Id_Partizione = @Id_Partizione
				AND Id_Tipo_Messaggio = '11000'

			-- Creo la missione per l'Udc
			EXEC @Return = dbo.sp_Insert_CreaMissioni
								@Id_Udc						= @Id_Udc,
								@Id_Partizione_Destinazione = 3102,
								@Id_Tipo_Missione			= 'ING',
								@Id_Missione				= @ID_MISSIONE	OUTPUT,
								@Id_Processo				= @Id_Processo,
								@Origine_Log				= @Origine_Log,
								@Id_Utente					= @Id_Utente,
								@Errore						= @Errore		OUTPUT

			DELETE	Eventi
			WHERE	Id_Evento = @Id_Evento
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
