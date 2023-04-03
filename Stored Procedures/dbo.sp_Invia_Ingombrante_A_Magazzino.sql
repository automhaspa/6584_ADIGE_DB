SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_Invia_Ingombrante_A_Magazzino]
	@Id_Udc						INT,
	@Id_Evento					INT = NULL,
	@Id_Udc_Ingombrante			INT,
	-- Parametri Standard;
	@Id_Processo				VARCHAR(30),
	@Origine_Log				VARCHAR(25),
	@Id_Utente					VARCHAR(16),
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
		IF NOT EXISTS (SELECT 1 FROM dbo.Udc_Posizione WHERE ID_UDC = @Id_Udc AND Id_Partizione = 3101)
			THROW 50001,'AZIONE NON ESEGUIBILE SU UNA BAIA DIVERSA DALLA 3A',1

		EXEC dbo.sp_Delete_EliminaUdc
			@Id_Udc			= @Id_Udc,
		    @Id_Processo	= @Id_Processo,
		    @Origine_Log	= @Origine_Log,
		    @Id_Utente		= @Id_Utente,
		    @Errore			= @Errore OUTPUT
		
		UPDATE	dbo.Udc_Posizione
		SET		Id_Partizione = 3101
		WHERE	Id_Udc = @Id_Udc_Ingombrante

		DELETE	dbo.Eventi
		WHERE	Id_Evento = 3101

		--SONO ANCORA NELLA SEZIONE LU_ON_ASI
		DECLARE @Id_Partizione_Destinazione INT
		DECLARE @ID_MISSIONE				INT

		SELECT	@Id_Partizione_Destinazione = Id_Partizione_OK
		FROM	dbo.Procedure_Personalizzate_Gestione_Messaggi
		WHERE	Id_Tipo_Messaggio = '11000'
			AND Id_Partizione = 3101

		-- Creo la missione per l'Udc			
		EXEC @Return = dbo.sp_Insert_CreaMissioni
				@Id_Udc						= @Id_Udc_Ingombrante,
				@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
				@Id_Tipo_Missione			= 'ING',
				@Id_Missione				= @ID_MISSIONE OUTPUT,
				@Id_Processo				= @Id_Processo,
				@Origine_Log				= @Origine_Log,
				@Id_Utente					= @Id_Utente,
				@Errore						= @Errore OUTPUT

		IF	@ID_MISSIONE = 0
				OR
			ISNULL(@Errore, '') <> ''
			THROW 50001, 'IMPOSSIBILE CREARE MISSIONE DI INGRESSO PER L''UDC', 1
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
