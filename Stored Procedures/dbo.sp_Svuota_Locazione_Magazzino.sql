SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Svuota_Locazione_Magazzino]
	@Id_Udc						INT,
	@Id_Partizione_Destinazione INT,
	@Id_Tipo_Quota				INT = NULL,
	@Id_Evento					INT,
	-- Parametri Standard;
	@Id_Processo				VARCHAR(30),
	@Origine_Log				VARCHAR(25),
	@Id_Utente					VARCHAR(32),	
	@Errore						VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
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
		UPDATE	Udc_Posizione
		SET		QuotaDepositoX =	CASE
										WHEN @Id_Tipo_Quota = -920	THEN 10
										WHEN @Id_Tipo_Quota = 0		THEN 820
										WHEN @Id_Tipo_Quota = +920	THEN 1630
									END
		WHERE	Id_Udc = @Id_Udc

		-- Dichiarazioni Variabili;
		IF @Id_Tipo_Quota IS NULL
			THROW 50008, 'POSIZIONE UDC NON SELEZIONATA',1

		EXEC @Return = sp_Insert_CreaMissioni
				@Id_Udc                     = @Id_Udc,
				@Id_Tipo_Missione           = 'OUT',
				@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
				@Priorita                   = 5,
				@Id_Processo                = @Id_Processo,
				@Origine_Log                = @Origine_Log,
				@Id_Utente                  = @Id_Utente,
				@Errore                     = @Errore OUTPUT;

		IF @Return <> 0
			RAISERROR(@Errore,12,1)

		DELETE	Eventi
		WHERE	Id_Evento = @Id_Evento

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
