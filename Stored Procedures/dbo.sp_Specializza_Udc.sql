SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_Specializza_Udc]
	@Id_Evento				INT,
	@Id_Udc					INT,
	@Id_Testata_Ddt_Reale	INT,
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
		DECLARE @Id_Partizione int;
		--L'Id del Ddt della Udc mi arriva durante l'importazione delle bolle se non ce l'ho Lo faccio selezionare all'utente?? per ora tiro eccezione	
		IF (ISNULL(@Id_Testata_Ddt_Reale, '') = '')					
			THROW 50004, 'Nessun Ddt associato per l Udc', 1;
		--Mi salvo la partizione del nuovo evento
		SELECT @Id_Partizione = e.Id_Partizione FROM Eventi e WHERE Id_Evento = @Id_Evento 
		--Se non c'è già un evento attivo su quella partizione
		IF (EXISTS(SELECT 1 FROM Eventi e WHERE Id_Tipo_Evento = 32 AND Id_Partizione = @Id_Partizione))
			THROW 50005, ' Evento già presente,  controlla gli eventi attivi', 1;
		--Lancio evento specializzazione righe Ddt
		DECLARE @Id_Tipo_Evento int = 32		 
        DECLARE @XmlParam XML = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc><Id_Ddt_Reale>',@Id_Testata_Ddt_Reale,'</Id_Ddt_Reale></Parametri>');												
		-- Creazione dell'evento solo se la  missione è terminata,altrimenti do il Confirm.
		EXEC @Return = sp_Insert_Eventi
						@Id_Tipo_Evento		= @Id_Tipo_Evento,
						@Id_Partizione		= @Id_Partizione,
						@Id_Tipo_Messaggio	= 1100,
						@XmlMessage			= @XmlParam,
						@id_evento_padre	= @Id_Evento,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore OUTPUT;
		IF @Return <> 0 RAISERROR(@Errore,12,1);
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
