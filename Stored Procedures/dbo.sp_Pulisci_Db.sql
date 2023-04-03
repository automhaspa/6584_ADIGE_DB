SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_Pulisci_Db]
	@Giorni_Storico_Da_Tenere INT = 14,
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

		DELETE	Messaggi_Inviati
		WHERE	DATEDIFF(day, DATA_ORA, GETDATE()) > @Giorni_Storico_Da_Tenere
			AND ID_Tipo_Stato_Messaggio <> 9
			AND Id_Messaggio NOT IN (SELECT Id_Messaggio FROM Messaggi_Percorsi)
		
		DELETE	Messaggi_Ricevuti
		WHERE	DATEDIFF(day, DATA_ORA, GETDATE()) > @Giorni_Storico_Da_Tenere
			AND ID_Tipo_Stato_Messaggio <> 9

		--Ripulisco i log di errore che rimangono storic
		DELETE	Log
		WHERE	DATEDIFF(day, DataOra_Log, GETDATE()) >= 30
			AND Id_Tipo_Log = 4
			AND Proprietà_Log NOT LIKE '%Modula%'

		--I LOG PER ERRORI DI PROCEDURA MODULA LI PULISCO OGNI NOTTE, TANTO SI RIPETONO FINTANTO CHE NON SISTEMANO I RERCORD DALLE TABELLE DI SCAMBIO			
		;WITH erroriModulaDuplicati AS
		(
			SELECT	Messaggio,
					Origine_Log,
					ROW_NUMBER() OVER(PARTITION BY Messaggio, Origine_Log ORDER BY DataOra_Log) AS [rn]
			FROM	Log
			WHERE	Proprietà_Log LIKE '%Modula%'
				AND Id_Tipo_Log = 4
		)
		DELETE	erroriModulaDuplicati
		WHERE	[rn] > 1

		;WITH logModulaDuplicati AS
		(
			SELECT	Messaggio,
					Origine_Log,
					ROW_NUMBER() OVER(PARTITION BY Messaggio, Origine_Log ORDER BY DataOra_Log) AS [rn]
			FROM	Log
			WHERE	Proprietà_Log LIKE '%Modula%'
				AND Id_Tipo_Log = 8
		)
		DELETE	logModulaDuplicati
		WHERE	[rn] > 1

		--Ripulisco lo storico missioni di Udc inesistenti la cui missione è di 3 mesi prima
		DELETE	Missioni_Storico
		WHERE	Id_Udc NOT IN (SELECT Id_Udc FROM Udc_Testata)
			AND	DATEDIFF(day, Data, GETDATE()) > 90

		--Ripulisco i log di info dopo 3 mesi
		DELETE	Log
		WHERE	Id_Tipo_Log <> 4
			AND	DATEDIFF(day, DataOra_Log, GETDATE()) > 90
		
		DELETE	ApplicationsLog

		DELETE	[L3INTEGRATION].[dbo].[HOST_STOCK_SUMMARY]
		WHERE	DATEDIFF(day, DT_ELAB, GETDATE()) > @Giorni_Storico_Da_Tenere

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
