SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROC [dbo].[sp_Chiudi_Evento_Ingombranti]
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
	SET @Nome_StoredProcedure	= Object_Name(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount				= @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		DECLARE @ID_TESTATA_LISTA	INT
		DECLARE @ID_EVENTO			INT

		DECLARE CURSORE_EVENTI_VUOTI CURSOR LOCAL FAST_FORWARD FOR
			SELECT	Id_Evento,
					Xml_Param.value('data(//Id_Testata_Lista)[1]','int')
			FROM	EVENTI
			WHERE	Id_Tipo_Evento = 6
				AND Xml_Param.value('data(//Id_Testata_Lista)[1]','int') <> 0

		OPEN CURSORE_EVENTI_VUOTI
		FETCH NEXT FROM CURSORE_EVENTI_VUOTI INTO
			@ID_EVENTO,
			@ID_TESTATA_LISTA

		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF NOT EXISTS	(
								SELECT	TOP 1 1
								FROM	AwmConfig.vRighePrelievoAttive
								WHERE	Id_Testata_Lista = @Id_Testata_Lista
									AND Nome_Magazzino = 'INGOMBRANTI'
							)
				DELETE	Eventi
				WHERE	Id_Evento = @Id_Evento

			FETCH NEXT FROM CURSORE_EVENTI_VUOTI INTO
				@ID_EVENTO,
				@ID_TESTATA_LISTA
		END

		CLOSE CURSORE_EVENTI_VUOTI
		DEALLOCATE CURSORE_EVENTI_VUOTI

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
