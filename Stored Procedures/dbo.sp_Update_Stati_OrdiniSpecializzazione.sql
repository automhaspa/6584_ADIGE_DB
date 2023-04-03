SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_Update_Stati_OrdiniSpecializzazione]
	@Id_Ddt_Fittizio	INT,
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
		--Controllo lo stato di tutto l'ordine di entrata basandomi sullo stato delle sue righe
		DECLARE @CountUdcTot			INT = (SELECT COUNT(Id_Udc) FROM Udc_Testata WHERE Id_Ddt_Fittizio = @Id_Ddt_Fittizio)
		
		DECLARE @CountUdcDichiarate		INT = (SELECT (N_Udc_Tipo_A + N_Udc_Tipo_B + N_Udc_Ingombranti + N_Udc_Ingombranti_M) FROM Custom.AnagraficaDdtFittizi WHERE ID = @Id_Ddt_Fittizio)
		DECLARE @StatoDdt				INT = (SELECT Id_Stato FROM Custom.AnagraficaDdtFittizi WHERE ID = @Id_Ddt_Fittizio)
		DECLARE @DdtAssociati			INT = (SELECT COUNT(ID) FROM Custom.TestataOrdiniEntrata WHERE Id_Ddt_Fittizio = @Id_Ddt_Fittizio)
		
		--Se corrispondono chiudo l'ordine di specializzazione
		IF	(
				@CountUdcDichiarate = @CountUdcTot
				AND
				@CountUdcTot > 0
				AND
				@DdtAssociati > 0
				--Tutte le Udc sono con flag specializzazione completata
				AND NOT EXISTS(SELECT 1 FROM Udc_Testata WHERE Id_Ddt_Fittizio = @Id_Ddt_Fittizio AND Specializzazione_Completa = 0)
				--Tutti i DDT reali ASSOCIATI sono stati completati
				AND NOT EXISTS(SELECT 1 FROM Custom.TestataOrdiniEntrata WHERE Id_Ddt_Fittizio = @Id_Ddt_Fittizio AND Stato IN (1,2))
			)
			--Chiudi quei DDT fittizi rimasti in stato specializzazione in corso
			--Che hanno tutti i ddt reali associati specalizzati e a cui è stata eliminata almeno un Udc (per picking o outbound o altro) rispetto a quelle dichiarate
			--(Sono sicuro che prima dell'avvio erano tutte a magazzino) per le udc il cui materiale va tutto in modula
			OR
			(
				@StatoDdt = 2
				AND @DdtAssociati > 0
				AND NOT EXISTS(SELECT 1 FROM Udc_Testata WHERE Id_Ddt_Fittizio = @Id_Ddt_Fittizio AND Specializzazione_Completa = 0)
				AND @CountUdcTot < @CountUdcDichiarate
				AND NOT EXISTS(SELECT 1 FROM Custom.TestataOrdiniEntrata WHERE Id_Ddt_Fittizio = @Id_Ddt_Fittizio AND Stato IN (1,2))
				--Controllo anche il tempo...se dopo 3 settimane è ancora lì in stato "specializzazione in corso" ma nessuno fa nulla lo chiudo
				--AND EXISTS (SELECT 1 FROM Custom.AnagraficaDdtFittizi WHERE ID = @Id_Ddt_Fittizio AND DATEDIFF(day, DataOra_Creazione, GETDATE()) > 21)
			)
		BEGIN
			UPDATE	Custom.AnagraficaDdtFittizi
			SET		Id_Stato = 3
			WHERE	ID = @Id_Ddt_Fittizio

			--ELIMINO DALLA TABELLA DI SCAMBIO 
			DELETE	L3INTEGRATION.dbo.HOST_LOAD_BILL
			WHERE	LOAD_BILL_ID = (SELECT Codice_DDT FROM Custom.AnagraficaDdtFittizi WHERE ID = @Id_Ddt_Fittizio)

			DECLARE @Msg varchar(500) = CONCAT (' AGGIORNATO STATO A COMPLETATO PER DDT FITTIZIO DI ID : ', @Id_Ddt_Fittizio)
			EXEC sp_Insert_Log
				@Id_Processo		= @Id_Processo,
				@Origine_Log		= @Origine_Log,
				@Proprieta_Log		= @Nome_StoredProcedure,
				@Id_Utente			= @Id_Utente,
				@Id_Tipo_Log		= 8,
				@Id_Tipo_Allerta	= 0,
				@Messaggio			= @Msg,
				@Errore				= @Errore OUTPUT;
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
