SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_ImpostaMotivoNC_Prelievo]
	@LINE_ID			INT,
	@Id_Testata_Lista	INT,
	@Motivo_NC			VARCHAR(25)	 = NULL,
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
		-- Dichiarazioni Variabili;
		DECLARE @Id_Riga_Lista INT 

		SELECT	@Id_Riga_Lista = ID
		FROM	Custom.RigheListePrelievo
		WHERE	Id_Testata = @Id_Testata_Lista
			AND LINE_ID = @LINE_ID

		IF @Id_Riga_Lista IS NULL
			THROW 50009, 'ERRORE NEL CONTROLLO DELLA RIGA SELEZIONATA',1

		IF NOT EXISTS (SELECT TOP 1 1 FROM Custom.RigheListePrelievo WHERE ID = @Id_Riga_Lista AND Id_Testata = @Id_Testata_Lista AND Magazzino = '0020')
			THROW 50009, 'MOTIVO NON CONFORMITA IMPOSTABILE SOLO PER PRELIEVI DA MAGAZZINO 20 (NON CONFORMI)',1

		UPDATE	Custom.RigheListePrelievo
		SET		Motivo_Nc = @Motivo_NC
		WHERE	ID = @Id_Riga_Lista
			AND Id_Testata = @Id_Testata_Lista

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
