SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_Update_Aggiorna_Missioni_Dettaglio]
	@Id_UdcDettaglio	INT,
	@Id_Dettaglio		INT,
	@Qta_Orig			NUMERIC(18,0),
	@Qta_Pezzi			NUMERIC(18,0) = NULL,
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

		-- Inserimento del codice;
		
		IF(@Qta_Pezzi IS NOT NULL)
		BEGIN

			-- SE LA @QTA_PEZZI E' NEGATIVA O UGUALE A 0 THROWO UNA ECCEZIONE
			IF(@Qta_Pezzi <= 0)
				THROW 50001, 'SpEx_QuantitaErrata', 1
			
			-- SE LA @QTA_PEZZI E' MAGGIORE DELLA QUANTITA' DA PRELEVARE THROWO UNA ECCEZIONE
			IF(@Qta_Pezzi > @Qta_Orig)
				THROW 50001, 'SpEx_QtaListaPrelevataTooMuch', 1
		END
        
		/*
			UNA VOLTA FINITI I CONTROLLI FACCIO:
				+ UPDATE MISSIONI_DETTAGLIO CON QUANTITA = @QTA_PEZZI / QTA_ORIG
				+ UPDATE STATO MISSIONI_DETTAGLIO A 5
		*/

		UPDATE	dbo.Missioni_Dettaglio
		SET		Quantita =	CASE 
								WHEN @Qta_Pezzi IS NOT NULL THEN @Qta_Pezzi 
								ELSE Qta_Orig 
							END,
				Id_Stato_Articolo = 5
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
		AND		Id_Dettaglio = @Id_Dettaglio

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
