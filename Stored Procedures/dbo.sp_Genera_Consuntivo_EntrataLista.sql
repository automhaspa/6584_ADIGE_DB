SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [dbo].[sp_Genera_Consuntivo_EntrataLista]	
	@Id_Testata_Ddt		INT,
	@Id_Riga_Ddt		INT,
	@Qta_Entrata		NUMERIC(18,4),
	@Fl_Quality_Check	INT				= 0,
	@Fl_Void			INT				= 0,
	@Id_Udc				INT				= NULL,
	@Miss_Qty			NUMERIC(10,2)	= NULL,
	@USERNAME			VARCHAR(32)		= NULL,
	@Doppio_Step_QM		BIT				= 0,
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
		DECLARE @CodiceUdc varchar(20)
		SELECT	@CodiceUdc = Codice_Udc
		FROM	Udc_Testata
		WHERE	Id_Udc = @Id_Udc

		--SCRITTURA TABELLA DI FRONTIERA
		IF NOT EXISTS	(
							SELECT	TOP(1) 1
							FROM	Custom.TestataOrdiniEntrata
							WHERE	ID = @Id_Testata_Ddt
								AND LOAD_ORDER_TYPE = 'RPO'
								AND DES_SUPPLIER_CODE <> 'IT30'
						)
		BEGIN
			INSERT INTO [L3INTEGRATION].[dbo].[HOST_INCOMING_SUMMARY]
				  ([DT_INS],[STATUS],[DT_ELAB],[USERNAME],[SUPPLIER_DDT_CODE],[DT_RECEIVE],[SUPPLIER_CODE],[LOAD_ORDER_ID],[LOAD_ORDER_TYPE],
						[LOAD_LINE_ID],[LINE_ID_ERP],[ITEM_CODE],[QUANTITY],[PURCHASE_ORDER_ID],[FL_INDEX_ALIGN],[FL_QUALITY_CHECK],[ACTUAL_QUANTITY],[ST_QUALITY],
						[REASON],[FL_VOID],[COMM_PROD],[COMM_SALE],[SUB_LOAD_ORDER_TYPE],[DOC_NUMBER],[REF_NUMBER],[NOTES],[MISS_QTY],WBS_ELEM)
			SELECT	TOP (1)
					GETDATE(),0,NULL,UPPER(ISNULL(@USERNAME, @Id_Utente)),ISNULL(toe.SUPPLIER_DDT_CODE, ' '),ISNULL(toe.DT_RECEIVE_BLM, ' '),ISNULL(toe.SUPPLIER_CODE, ' '),--toe.LOAD_ORDER_ID,
					CASE
						WHEN toe.LOAD_ORDER_TYPE = 'SPI' THEN CONCAT(TOE.LOAD_ORDER_ID, RIGHT('000000'+CAST(ROE.LOAD_LINE_ID AS VARCHAR(6)),6))
						ELSE toe.LOAD_ORDER_ID
					END,
					TOE.LOAD_ORDER_TYPE,
					roe.LOAD_LINE_ID,roe.LINE_ID_ERP,roe.ITEM_CODE,roe.QUANTITY,ISNULL(roe.PURCHASE_ORDER_ID, ' '),ISNULL(roe.FL_INDEX_ALIGN, 0),
					--Flag quality Check SE E' A 1 MA FACCIO LA CHIUSURA RIGA GLI RIMANDO LO STESSO FL_QUALITY_CHECK
					CASE
						WHEN @Fl_Quality_Check = 0 THEN roe.FL_QUALITY_CHECK
						ELSE @Fl_Quality_Check
					END,
					@Qta_Entrata,
					--Stato qualità ST_QUALITY
					CASE
						WHEN @Fl_Quality_Check = 1 AND @Doppio_Step_QM = 0 THEN 'BLOC'
						ELSE 'DISP'
					END,
					'',@Fl_Void,ISNULL(roe.COMM_PROD, ' '),ISNULL(roe.COMM_SALE, ' '),ISNULL(roe.SUB_LOAD_ORDER_TYPE, ' '),
					ISNULL(roe.DOC_NUMBER, ' '),ISNULL(roe.REF_NUMBER, ' '),ISNULL(@CodiceUdc, ' '),@Miss_Qty,roe.WBS_ELEM
			FROM	Custom.TestataOrdiniEntrata		toe
			JOIN	Custom.RigheOrdiniEntrata		roe
			ON		toe.ID = roe.Id_Testata
			WHERE	toe.ID = @Id_Testata_Ddt
				AND roe.LOAD_LINE_ID = @Id_Riga_Ddt

			declare @mess_log varchar(max) =CONCAT('HO INSERITO IL RECORD INC SUMMARY PER L''UDC ', @CODICEUDC)
			EXEC sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= @Nome_StoredProcedure,
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 4,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @mess_log,
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
