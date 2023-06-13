SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_Sospendi_Lista_Prelievo]
	--ID testata
	@ID				INT,
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
		DECLARE @Stato			INT = 0

		IF (ISNULL(@ID,0) = 0)
			THROW 50005, 'LISTA NON DEFINITA',1

		SELECT	@Stato = Stato
		FROM	Custom.TestataListePrelievo
		WHERE	ID = @ID

		IF @Stato = 0
			THROW 50006, 'STATO NON DEFINITO',1

		--POSSO SOSPENDERE SOLO LISTE IN ESECUZIONE
		IF	@Stato <> 2
			AND
			NOT EXISTS	(
							SELECT TOP 1 1
							FROM	Missioni_Picking_Dettaglio
							WHERE	Id_Testata_Lista = @ID
								AND Id_Udc <> 702
								AND Id_Stato_Missione IN (1,2)
						)
			THROW 50006, 'E'' POSSIBILE SOSPENDERE ESCLUSIVAMENTE LISTE IN ESECUZIONE',1

		UPDATE	Custom.TestataListePrelievo
		SET		Stato = 5
		WHERE	ID = @ID

		UPDATE	Missioni_Picking_Dettaglio
		SET		Id_Stato_Missione = 5,
				DataOra_UltimaModifica = GETDATE()
		WHERE	Id_Testata_Lista = @ID
			AND Id_Udc <> 702
			AND Id_Stato_Missione NOT IN (3,4)


		IF EXISTS(SELECT TOP 1 1 FROM EVENTI WHERE Id_Tipo_Evento = 7 AND Xml_Param.value('data(//Parametri//Id_Testata_Lista)[1]','int') = @ID)
		BEGIN
			DECLARE @ID_EVENTO INT

			SELECT	@ID_EVENTO = Id_Evento
			FROM	EVENTI
			WHERE	Id_Tipo_Evento = 7 AND Xml_Param.value('data(//Parametri//Id_Testata_Lista)[1]','int') = @ID

			DELETE	EVENTI
			WHERE	Id_Evento = @ID_EVENTO
		END

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
