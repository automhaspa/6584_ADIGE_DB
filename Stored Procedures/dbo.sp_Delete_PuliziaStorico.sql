SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_Delete_PuliziaStorico]
	@MessagesExpireDays		INT = 7,
	@LogExpireDays			INT = 30,
	@MissionExpireDays		INT = 30,
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
		-- Dichiarazioni Variabili;

		-- Inserimento del codice;
		DELETE Messaggi_Inviati		WHERE DATEDIFF(DAY,DATA_ORA,GETDATE())				>= @MessagesExpireDays	AND ID_TIPO_STATO_MESSAGGIO <> 1
		DELETE Messaggi_Ricevuti	WHERE DATEDIFF(DAY,DATA_ORA,GETDATE())				>= @MessagesExpireDays	AND ID_TIPO_STATO_MESSAGGIO <> 1
		DELETE Alarms				WHERE DATEDIFF(DAY,Date,GETDATE())					>= @LogExpireDays		
		DELETE ApplicationsLog		WHERE DATEDIFF(DAY,TimeStamp,GETDATE())				>= @LogExpireDays


		DELETE Printer.PrinterRequest	WHERE DATEDIFF(DAY,Data_Esecuzione,GETDATE())		>= 7 AND Id_Tipo_Stato_Messaggio <> 1
 		DELETE Log						WHERE DATEDIFF(DAY,DataOra_Log,GETDATE())			>= 7 AND Proprietà_Log = 'Tempistiche'
		DELETE Log						WHERE DATEDIFF(DAY,DataOra_Log,GETDATE())			>= 30 AND Origine_Log = 'l3integration.sp_Modula_I'

		
		--DELETE Missioni_Storico		WHERE DATEDIFF(DAY,Data,GETDATE())					>= @MissionExpireDays
		--									AND Codice_Udc NOT IN (SELECT Codice_Udc FROM Udc_Testata)
		--DELETE Movimenti			WHERE DATEDIFF(DAY,Data_Movimento,GETDATE())		>= @MissionExpireDays
		--									AND Id_Udc NOT IN (SELECT Id_Udc FROM Udc_Testata)
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
