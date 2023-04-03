SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Elimina_Ddt_Reale]
	@ID				INT,		--ID testata
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
		DECLARE @Stato_Testata	INT

		SELECT	@Stato_Testata = Stato
		FROM	Custom.TestataOrdiniEntrata
		WHERE	ID = @ID

		IF @Stato_Testata NOT IN (1,3,4)
			THROW 50001, 'IMPOSSIBILE ELIMINARE UN DDT IN ESECUZIONE O GIA CHIUSO', 1

		--DA GESTIRE IL CAMPO MISSQTY
		IF @Stato_Testata = 1
		BEGIN
			INSERT INTO [L3INTEGRATION].[dbo].[HOST_INCOMING_SUMMARY]
				([DT_INS],[STATUS],[DT_ELAB],[USERNAME],[SUPPLIER_DDT_CODE],[DT_RECEIVE],[SUPPLIER_CODE],[LOAD_ORDER_ID],[LOAD_ORDER_TYPE],
					[LOAD_LINE_ID],[LINE_ID_ERP],[ITEM_CODE],[QUANTITY],[PURCHASE_ORDER_ID],[FL_INDEX_ALIGN],[FL_QUALITY_CHECK],[ACTUAL_QUANTITY],[ST_QUALITY],
					[REASON],[FL_VOID],[COMM_PROD],[COMM_SALE],[SUB_LOAD_ORDER_TYPE],[DOC_NUMBER],[REF_NUMBER],[NOTES])
			SELECT	GETDATE(),0,NULL, UPPER(@Id_Utente), ISNULL(toe.SUPPLIER_DDT_CODE, ' '),ISNULL(toe.DT_RECEIVE_BLM, ' '),ISNULL(toe.SUPPLIER_CODE, ' '),toe.LOAD_ORDER_ID,toe.LOAD_ORDER_TYPE,
					roe.LOAD_LINE_ID,roe.LINE_ID_ERP,roe.ITEM_CODE,roe.QUANTITY,ISNULL(roe.PURCHASE_ORDER_ID, ' '),ISNULL(roe.FL_INDEX_ALIGN,0),ROE.FL_QUALITY_CHECK,0,'',
					NULL,1,ISNULL(roe.COMM_PROD, ' '),ISNULL(roe.COMM_SALE, ' '),ISNULL(roe.SUB_LOAD_ORDER_TYPE, ' '),ISNULL(roe.DOC_NUMBER, ' '),ISNULL(roe.REF_NUMBER, ' '), roe.NOTES
			FROM	Custom.TestataOrdiniEntrata		toe
			JOIN	Custom.RigheOrdiniEntrata		roe
			ON		toe.ID = roe.Id_Testata
			WHERE	toe.ID = @ID
				AND roe.Stato =	CASE 
									WHEN @Stato_Testata = 3 THEN 1
									ELSE roe.Stato
								END
								
			DELETE FROM Custom.RigheOrdiniEntrata WHERE Id_Testata = @ID
			DELETE FROM Custom.TestataOrdiniEntrata WHERE ID = @ID
		END
		IF @Stato_Testata = 3
		BEGIN
			INSERT INTO [L3INTEGRATION].[dbo].[HOST_INCOMING_SUMMARY]
				([DT_INS],[STATUS],[DT_ELAB],[USERNAME],[SUPPLIER_DDT_CODE],[DT_RECEIVE],[SUPPLIER_CODE],[LOAD_ORDER_ID],[LOAD_ORDER_TYPE],
					[LOAD_LINE_ID],[LINE_ID_ERP],[ITEM_CODE],[QUANTITY],[PURCHASE_ORDER_ID],[FL_INDEX_ALIGN],[FL_QUALITY_CHECK],[ACTUAL_QUANTITY],[ST_QUALITY],
					[REASON],[FL_VOID],[COMM_PROD],[COMM_SALE],[SUB_LOAD_ORDER_TYPE],[DOC_NUMBER],[REF_NUMBER],[NOTES])
			SELECT	GETDATE(),0,NULL, UPPER(@Id_Utente), ISNULL(toe.SUPPLIER_DDT_CODE, ' '),ISNULL(toe.DT_RECEIVE_BLM, ' '),ISNULL(toe.SUPPLIER_CODE, ' '),toe.LOAD_ORDER_ID,toe.LOAD_ORDER_TYPE,
					roe.LOAD_LINE_ID,roe.LINE_ID_ERP,roe.ITEM_CODE,roe.QUANTITY,ISNULL(roe.PURCHASE_ORDER_ID, ' '),ISNULL(roe.FL_INDEX_ALIGN,0),ROE.FL_QUALITY_CHECK,0,'',
					NULL,1,ISNULL(roe.COMM_PROD, ' '),ISNULL(roe.COMM_SALE, ' '),ISNULL(roe.SUB_LOAD_ORDER_TYPE, ' '),ISNULL(roe.DOC_NUMBER, ' '),ISNULL(roe.REF_NUMBER, ' '), roe.NOTES
			FROM	Custom.TestataOrdiniEntrata		toe
			JOIN	Custom.RigheOrdiniEntrata		roe
			ON		toe.ID = roe.Id_Testata
			WHERE	toe.ID = @ID
				AND roe.Stato =	CASE 
									WHEN @Stato_Testata = 3 THEN 1
									ELSE roe.Stato
								END

			 UPDATE	Custom.RigheOrdiniEntrata SET Stato = 2 WHERE Id_Testata = @ID
			 UPDATE Custom.TestataOrdiniEntrata SET Stato = 4 WHERE ID = @ID
		END
		IF @Stato_Testata = 4
		BEGIN
			DELETE FROM Custom.RigheOrdiniEntrata WHERE Id_Testata = @ID
			DELETE FROM Custom.TestataOrdiniEntrata WHERE ID = @ID
		END
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
