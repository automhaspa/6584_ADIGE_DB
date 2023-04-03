SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_WBS_Rimuovi_Udc]
	@Id_UdcDettaglio		INT,
	@Id_Udc					INT,
	@ID_WBS					VARCHAR(25),
	@Id_Articolo			INT,
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
	DECLARE @Nome_StoredProcedure	VARCHAR(30)
	DECLARE @TranCount				INT
	DECLARE @Return					INT
	DECLARE @ErrLog					VARCHAR(500)

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		SET @ID_WBS = SUBSTRING(@ID_WBS,2,LEN(@ID_WBS))
		
		DECLARE @Id_UdcDettaglio_DaAggiornare	INT
		SELECT	@Id_UdcDettaglio_DaAggiornare = Id_UdcDettaglio
		FROM	Udc_Dettaglio
		WHERE	Id_Articolo = @Id_Articolo
			AND WBS_Riferimento = ''
			AND Id_Udc = @Id_Udc
			AND Id_UdcDettaglio <> @Id_UdcDettaglio
		
		IF @Id_UdcDettaglio_DaAggiornare IS NOT NULL
		BEGIN
			DECLARE @Qta_Da_Accorpare				INT
			
			SELECT	@Qta_Da_Accorpare = Quantita_Pezzi
			FROM	Udc_Dettaglio
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio

			EXEC sp_WBS_Gestisci_Dettagli
					@Id_UdcDettaglio_Sorgente		= @Id_UdcDettaglio,
					@Id_UdcDettaglio_Destinazione	= @Id_UdcDettaglio_DaAggiornare,
					@Qta_DaAggiungere				= @Qta_Da_Accorpare,
					@Id_Processo					= @Id_Processo,
					@Origine_Log					= @Origine_Log,
					@Id_Utente						= @Id_Utente,
					@Errore							= @Errore						OUTPUT

			EXEC sp_Update_Aggiorna_Contenuto_Udc
						@Id_Udc					= @Id_Udc,
						@Id_UdcDettaglio		= @Id_UdcDettaglio,
						@Id_Causale_Movimento	= 6,
						@Id_Processo			= @Id_Processo,
						@Id_Utente				= @Id_Utente,
						@Origine_Log			= @Origine_Log,
						@Errore					= @Errore			OUTPUT
		END
		ELSE
			UPDATE	Udc_Dettaglio
			SET		WBS_Riferimento = ''
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
				AND WBS_Riferimento = @ID_WBS

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
