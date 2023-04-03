SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_Update_Stati_ListePrelievo]
	@Id_Testata_Lista	INT = NULL,
	-- Parametri Standard;
	@Id_Processo		VARCHAR(30),
	@Origine_Log		VARCHAR(25),
	@Id_Utente			VARCHAR(32),
	@Errore				VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT OFF;
	SET DEADLOCK_PRIORITY HIGH
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
		--DECLARE @CountLinee			INT
		--DECLARE @CountLineeEvase		INT
		--DECLARE @CountMancanti		INT
		DECLARE @Inevase			BIT = 0
		DECLARE @Mancanti			BIT = 0

		--RECORD DUPLICATI, IDTESTATA LISTA INEISTENTE CHE MANDAVA IN ECCEZIONE LA IF QUA SOTTO
		IF (ISNULL(@Id_Testata_Lista,0) <> 0)
		BEGIN
			--Controllo fine Lista
			--SELECT @CountLinee = COUNT(1) FROM Missioni_Picking_Dettaglio WHERE Id_Testata_Lista = @Id_Testata_Lista
			--SELECT @CountLineeEvase = COUNT(1) FROM Missioni_Picking_Dettaglio WHERE Id_Testata_Lista = @Id_Testata_Lista AND Id_Stato_Missione = 4
			--SELECT @CountMancanti = COUNT(1) FROM Custom.AnagraficaMancanti WHERE Id_Testata = @Id_Testata_Lista AND Qta_Mancante > 0)
			
			--IF (@CountLinee > 0 AND @CountLineeEvase > 0)
			--BEGIN
			--	IF (@CountLinee = @CountLineeEvase AND @CountMancanti = 0)
			--		UPDATE	Custom.TestataListePrelievo
			--		SET		Stato = 4
			--		WHERE	ID = @Id_Testata_Lista
			--	ELSE IF (@CountLinee = @CountLineeEvase AND @CountMancanti > 0)
			--		UPDATE	Custom.TestataListePrelievo
			--		SET		Stato = 3
			--		WHERE	ID = @Id_Testata_Lista
			--END
			
			IF EXISTS(SELECT TOP 1 1 FROM Custom.AnagraficaMancanti WHERE Id_Testata = @Id_Testata_Lista AND Qta_Mancante > 0)
				SET @Mancanti = 1

			IF EXISTS(SELECT TOP 1 1 FROM Missioni_Picking_Dettaglio WHERE Id_Testata_Lista = @Id_Testata_Lista AND Id_Stato_Missione <> 4)
				SET @Inevase = 1

			IF	@Inevase = 0
					AND
				EXISTS (SELECT TOP 1 1 FROM Missioni_Picking_Dettaglio WHERE Id_Testata_Lista = @Id_Testata_Lista)
			BEGIN
				IF @Mancanti = 0
					UPDATE	Custom.TestataListePrelievo
					SET		Stato = 4
					WHERE	ID = @Id_Testata_Lista
				ELSE
					UPDATE	Custom.TestataListePrelievo
					SET		Stato = 3
					WHERE	ID = @Id_Testata_Lista
			END
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
