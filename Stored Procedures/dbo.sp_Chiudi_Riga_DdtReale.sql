SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Chiudi_Riga_DdtReale]
	@Id_Evento		INT = NULL,
	@Id_Testata		INT,
	@NUMERO_RIGA	INT,
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
	DECLARE @Nome_StoredProcedure	VARCHAR(30)
	DECLARE @TranCount				INT
	DECLARE @Return					INT
	DECLARE @ErrLog					VARCHAR(500)

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		DECLARE @Sospendi_Consuntivo BIT = 0

		IF EXISTS(SELECT TOP 1 1 FROM Custom.TestataOrdiniEntrata WHERE ID = @Id_Testata AND Stato NOT IN (1,2))
			THROW 50001, ' IMPOSSIBILE FORZARE LA CHIUSURA DI UNA RIGA DI UNA LISTA GIA'' CHIUSA',1

		IF	EXISTS	(
						SELECT	TOP(1) 1
						FROM	Custom.RigheOrdiniEntrata
						WHERE	Id_Testata = @Id_Testata
							AND LOAD_LINE_ID = @NUMERO_RIGA
							AND Stato = 2
					)
			THROW 50001, ' IMPOSSIBILE FORZARE LA CHIUSURA DI UNA RIGA GIA'' IN STATO CHIUSO',1

		DECLARE @Miss_Qty NUMERIC(10,2)
		DECLARE @FlagCqL3 BIT

		SELECT	@Miss_Qty = ISNULL(QUANTITA_RIMANENTE_DA_SPECIALIZZARE, 0),
				@FlagCqL3 = FLAG_CONTROLLO_QUALITA
		FROM	AwmConfig.vQtaRimanentiRigheDdt
		WHERE	ID_RIGA = @NUMERO_RIGA
			AND Id_Testata = @Id_Testata

		--DEVO MANDARE IL CONSUNTIVO SOLO E SOLO SE ANCHE MODULA HA MANDATO I CONSUNTIVI
		IF @Miss_Qty > 0
		BEGIN
			DECLARE @QTA_TOTALE				NUMERIC(18,4)
			DECLARE @QTA_CONSUNTIVATA		NUMERIC(18,4)
			DECLARE @ITEM_CODE				VARCHAR(18)
			DECLARE @PURCHASE_ORDER_ID		VARCHAR(15)

			SELECT	@QTA_TOTALE = ROE.QUANTITY,
					@QTA_CONSUNTIVATA = ISNULL(SUM(HIS.ACTUAL_QUANTITY),0),
					@ITEM_CODE = ROE.ITEM_CODE,
					@PURCHASE_ORDER_ID = ROE.PURCHASE_ORDER_ID
			FROM	Custom.TestataOrdiniEntrata						TOE
			JOIN	Custom.RigheOrdiniEntrata						ROE
			ON		ROE.Id_Testata = TOE.ID
			LEFT
			JOIN	L3INTEGRATION.DBO.HOST_INCOMING_SUMMARY			HIS
				ON	TOE.LOAD_ORDER_ID = HIS.LOAD_ORDER_ID
				AND TOE.LOAD_ORDER_TYPE = HIS.LOAD_ORDER_TYPE
				AND ROE.LOAD_LINE_ID = HIS.LOAD_LINE_ID
			WHERE	Id_Testata = @Id_Testata
				AND ROE.LOAD_LINE_ID = @NUMERO_RIGA
			GROUP
				BY	ROE.QUANTITY,
					ROE.ITEM_CODE,
					ROE.PURCHASE_ORDER_ID

			IF @QTA_TOTALE - @QTA_CONSUNTIVATA > @Miss_Qty --SIGNIFICA CHE HO QUALCOSA IN MODULA CHE ANCORA NON E' SCESO
			BEGIN
				INSERT INTO Custom.RigheOrdiniEntrata_Sospeso
					(ID_TESTATA, LOAD_LINE_ID, ITEM_CODE, PURCHASE_ORDER_ID, QTA_TOTALE, QTA_DA_CONSUNTIVARE, QTA_DA_STORNARE)
				VALUES
					(@Id_Testata, @NUMERO_RIGA, @ITEM_CODE, @PURCHASE_ORDER_ID, @QTA_TOTALE, (@QTA_TOTALE - @QTA_CONSUNTIVATA), @Miss_Qty)

				SET @Sospendi_Consuntivo = 1
			END
		END
		
		--SE HO IL FLAG SULLA RIGA DELL'ORDINE L3 VUOL DIRE CHE SONO NEL CASO 2 STEP QM (SAP) E DEVO VALORIZZARE MISSQTY ALTRIMENTI NO.
		IF ISNULL(@FlagCqL3,0) = 0
			SET @Miss_Qty = NULL

		IF @Sospendi_Consuntivo = 0
		BEGIN
			EXEC [dbo].[sp_Genera_Consuntivo_EntrataLista]
						@Id_Testata_Ddt		= @Id_Testata,
						@Id_Riga_Ddt		= @NUMERO_RIGA,
						@Qta_Entrata		= 0,
						@Fl_Quality_Check	= 0,
						@Fl_Void			= 1,
						@Miss_Qty			= @Miss_Qty,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore		OUTPUT
		
			IF (ISNULL(@Errore, '') <> '')
				THROW 50006, @Errore, 1
		END

		--Forzo la chiusura della riga
		EXEC [dbo].[sp_Update_Stati_OrdiniEntrata]
					@Id_Evento		= @Id_Evento,
					@Id_Riga		= @NUMERO_RIGA,
					@Id_Testata		= @Id_Testata,
					--FONDAMENTALE QUANTITA A 0
					@FlagChiusura	= 1,
					@Id_Processo	= @Id_Processo,
					@Origine_Log	= @Origine_Log,
					@Id_Utente		= @Id_Utente,
					@Errore			= @Errore		OUTPUT

		IF (ISNULL(@Errore, '') <> '')
			THROW 50006, @Errore, 1

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
