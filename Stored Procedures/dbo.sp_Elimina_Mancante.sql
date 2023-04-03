SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Elimina_Mancante]
	@Id_Evento			INT,
	@Id_Testata			INT,
	@Id_Articolo		INT,
	@Id_Riga			INT,
	@Id_Udc				INT,
	@Missione_Modula	INT = 0,
	@Invia_Dati_A_Sap	BIT = 1,
	-- Parametri Standard;
	@Id_Processo		VARCHAR(30),
	@Origine_Log		VARCHAR(25),
	@Id_Utente			VARCHAR(32),
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
		--Aggiorno la tabella Mancanti con quantita a 0 per chiudere la riga
		UPDATE	Custom.AnagraficaMancanti
		SET		Qta_Mancante = 0
		WHERE	Id_Testata = @Id_Testata
			AND Id_Riga = @Id_Riga
		
		--Controllo lo stato lista
		EXEC [dbo].[sp_Update_Stati_ListePrelievo]
				@Id_Testata_Lista	= @Id_Testata,
				@Id_Processo		= @Id_Processo,
				@Origine_Log		= @Origine_Log,
				@Id_Utente			= @Id_Utente,
				@Errore				= @Errore			OUTPUT

		EXEC sp_Genera_Consuntivo_Mancanti
			@Id_Testata		= @Id_Testata,
			@Id_Riga		= @Id_Riga,
			@Id_Articolo	= @Id_Articolo,
			@Qta_Prelievo	= 0,
			@Id_Processo	= @Id_Processo,
			@Origine_Log	= @Origine_Log,
			@Id_Utente		= @Id_Utente,
			@Errore			= @Errore			OUTPUT

		--Controllo se ci sono ancora
		IF NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	AwmConfig.vUdcPrelievoMancanti
							WHERE	Id_Udc = @Id_Udc
								AND Id_Articolo = @Id_Articolo
						)
		BEGIN
			EXEC [dbo].[sp_Chiudi_Prelievo_Mancanti]
						@Missione_Modula	= @Missione_Modula,
						@Id_Evento			= @Id_Evento,
						@Id_Udc				= @Id_Udc,
						@Invia_Dati_A_Sap	= @Invia_Dati_A_Sap,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore OUTPUT
			IF (ISNULL(@Errore, '') <> '')
				THROW 50002, @Errore, 1;
		END

		UPDATE	Missioni_Picking_Dettaglio
		SET		Id_Stato_Missione =	4,
				DataOra_Evasione = GETDATE()
		WHERE	Id_Testata_Lista = @Id_Testata
			AND Id_Riga_Lista = @Id_Riga
			AND FL_MANCANTI = 1
			AND Id_Stato_Missione = 2


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
