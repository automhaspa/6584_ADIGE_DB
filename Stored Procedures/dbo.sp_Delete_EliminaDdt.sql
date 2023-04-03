SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Delete_EliminaDdt]
	--Id univoco del DDT
	@ID				INT			= 0,
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
		--Elimino dalla tabella le Udc fittizie anagrafate con quel Id_DDT se non sono in magazzino
		DECLARE @ID_UDC INT

		IF @ID = 0
			THROW 51000, 'ID NON VALORIZZATO', 1

		--Se un Udc riferita al DDT che voglio eliminare è già in magazzino non permetto l'eliminazione del DDT fittizio
		IF EXISTS (SELECT 1 FROM Udc_Posizione up WHERE up.Id_Udc IN (SELECT Id_Udc FROM Udc_Testata WHERE Id_Udc = up.Id_Udc AND Id_Ddt_Fittizio = @ID))
			THROW 51000, 'Impossibile eliminare un DDT se ci sono Udc anagrafate con quel codice già presenti magazzino', 1

		IF EXISTS (SELECT 1 FROM Custom.TestataOrdiniEntrata WHERE Id_Ddt_Fittizio = @ID AND Stato NOT IN (3,4))
			THROW 50001, 'Impossibile eliminare un DDT se ci sono DDT reale associati non chiusi', 1

		--ELIMINO DALLA TABELLA DI SCAMBIO 
		DELETE	L3INTEGRATION.dbo.HOST_LOAD_BILL
		WHERE	LOAD_BILL_ID =	(
									SELECT	Codice_DDT
									FROM	Custom.AnagraficaDdtFittizi
									WHERE	ID = @ID
								)

		--Elimino tutte le Udc riferite a quel DDT
		DELETE	dbo.Udc_Testata
		WHERE	Id_Ddt_Fittizio = @ID
		
		--Elimino il record del DDT dalla tabella anagrafica
		DELETE	Custom.AnagraficaDdtFittizi
		WHERE	ID = @ID

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
