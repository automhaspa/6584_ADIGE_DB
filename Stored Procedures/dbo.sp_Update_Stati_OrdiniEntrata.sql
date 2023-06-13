SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_Update_Stati_OrdiniEntrata]
	@Id_Evento			INT = NULL,
	@Id_Riga			INT = NULL,
	@Id_Testata			INT,
	@FlagChiusura		BIT = 0,
	@SpecIngombranti	BIT = 0,
	@SpecModula			BIT = 0,
	--@FlVoid bit = 0,
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
		--Se ho specificato Id_Riga e Id_Testata significa che provengo da specializzazione manuale
		--Controllo la quantità rimanente per fare l'update dello stato riga
		IF ISNULL(@Id_Riga, 0) <> 0 AND ISNULL(@Id_Testata, 0) <> 0
		BEGIN
			IF @FlagChiusura = 0
			BEGIN
				DECLARE @QuantitaRimanenteRiga	NUMERIC(10,2) = 0

				--DIFFERENZIAZIONE TRA EVENTO INGOMBRANTI E EVENTO IN BAIA PER  PUNTARE A 2 VISTE DIVERSE E' UNA STRONZATA MA C'E' STATO UN CAMBIAMENTO NEI FLUSSI NON PREVISTO
				IF @SpecIngombranti = 1
					SELECT	@QuantitaRimanenteRiga = QUANTITA_RIMANENTE_DA_SPECIALIZZARE
					FROM	AwmConfig.vRigheDdtDaSpcCompleta
					WHERE	NUMERO_RIGA = @Id_Riga
						AND Id_Testata = @Id_Testata
				ELSE
					SELECT	@QuantitaRimanenteRiga = QUANTITA_RIMANENTE_DA_SPECIALIZZARE
					FROM	AwmConfig.vQtaRimanentiRigheDdt
					WHERE	ID_RIGA = @Id_Riga
						AND Id_Testata = @Id_Testata

				--Se ho specializzato tutta Aggiorno lo stato a elaborato
				IF @QuantitaRimanenteRiga = 0
					UPDATE	Custom.RigheOrdiniEntrata
					SET		Stato = 2
					WHERE	LOAD_LINE_ID = @Id_Riga
						AND Id_Testata = @Id_Testata
			END
			--Se c'è il flag chiusura forzata me ne frego delle quantità
			ELSE
				UPDATE	Custom.RigheOrdiniEntrata
				SET		Stato = 2
				WHERE	LOAD_LINE_ID = @Id_Riga
					AND Id_Testata = @Id_Testata
		END

		IF (@SpecIngombranti = 0 AND @SpecModula <> 1)
		BEGIN
			--Controllo lo stato di tutto l'ordine di entrata basandomi sullo stato delle sue righe
			DECLARE @CountLinee			INT	= (SELECT COUNT(1) FROM Custom.RigheOrdiniEntrata WHERE Id_Testata = @Id_Testata)
			DECLARE @CountLineeChiuse	INT = (SELECT COUNT(1) FROM Custom.RigheOrdiniEntrata WHERE Id_Testata = @Id_Testata AND Stato = 2)
			
			--Stato chiuso
			IF @CountLinee = @CountLineeChiuse
			BEGIN
				UPDATE	Custom.TestataOrdiniEntrata
				SET		Stato = 3
				WHERE	ID = @Id_Testata

				--Elimino l'evento di specializzazione righe
				IF @Id_Evento IS NOT NULL
					DELETE	Eventi
					WHERE	Id_Evento = @Id_Evento
				
				-->SPECIALIZZAZIONE A TERRA ELIMINA L'EVENTO IN AUTOMATICO

				-->DA RICONTROLLARE LA CHIUSURA AUTOMATICA DEGLI EVENTI E LO STATO SPECIALIZZAZIONE COMPLETA
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
