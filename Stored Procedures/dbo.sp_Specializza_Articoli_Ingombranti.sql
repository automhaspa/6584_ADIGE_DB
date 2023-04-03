SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[sp_Specializza_Articoli_Ingombranti]
	@Id_Ddt_Fittizio	INT,
	@Id_Udc				INT,
	@Id_Evento			INT,
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
		DECLARE @IdPartizEv		INT
		
		SELECT	@IdPartizEv = Id_Partizione
		FROM	Eventi
		WHERE	Id_Evento = @Id_Evento

		IF EXISTS	(
						SELECT	TOP 1 1
						FROM	Eventi
						WHERE	Id_Tipo_Stato_Evento = 1
							AND Id_Tipo_Evento = 43
							AND Id_Partizione = @IdPartizEv
					)
			THROW 50001, ' EVENTO DI SPECIALIZZAZIONE ARTICOLI PER INGOMBRANTE GIA ATTIVO, CHIUDERE IL PRECEDENTE', 1

		--INSERISCO L'EVENTO DI SPECIALIZZAZIONE RIGHE DDT FITTIZIO
		DECLARE @Action XML = CONCAT('<Parametri><Id_Ddt_Fittizio>',@Id_Ddt_Fittizio,'</Id_Ddt_Fittizio><Id_Udc>', @Id_Udc ,'</Id_Udc></Parametri>')

		EXEC [dbo].[sp_Insert_Eventi]
				@Id_Tipo_Evento		= 43,
				@Id_Partizione		= @IdPartizEv,
				@Id_Tipo_Messaggio	= '1100',
				@XmlMessage			= @Action,
				@id_evento_padre	= @Id_Evento,
				@Id_Processo		= @Id_Processo,
				@Origine_Log		= @Origine_Log,
				@Id_Utente			= @Id_Utente,
				@Errore				= @Errore	OUTPUT

		IF ISNULL(@Errore, '') <> ''
			RAISERROR(@Errore,12,1)

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
