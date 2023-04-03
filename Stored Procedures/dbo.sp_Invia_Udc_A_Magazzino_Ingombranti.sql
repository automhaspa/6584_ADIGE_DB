SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Invia_Udc_A_Magazzino_Ingombranti]
	@Id_Udc						INT,
	@Id_Partizione_Destinazione	INT,
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
		IF NOT EXISTS
		(
			SELECT	1
			FROM	dbo.Udc_Posizione	UP
			JOIN	dbo.Udc_Testata		UT
			ON		UT.Id_Udc = UP.Id_Udc
			WHERE	UP.ID_UDC = @Id_Udc
				AND UP.Id_Partizione = 3203
		)
			THROW 50009, 'OPERAZIONE POSSIBILE SOLO DA BAIA 3B03',1

		UPDATE	dbo.Udc_Posizione
		SET		Id_Partizione = @Id_Partizione_Destinazione
		WHERE	Id_Udc = @Id_Udc

		DELETE	dbo.Eventi
		WHERE	Id_Partizione = 3203

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
