SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_Aggiungi_Materiale_MovimentoReso]
	@CODICE_MATERIALE	VARCHAR(MAX),
	@Qty				NUMERIC(10,2),
	@Causale			VARCHAR(3),
	@Sign				VARCHAR(1),
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
		
		--CONSUNTIVAZIONE L3 CON UBL
		INSERT INTO [L3INTEGRATION].[dbo].[HOST_MOVEMENTS_SUMMARY]
			([DT_INS],[STATUS],[DT_ELAB],[USERNAME],[SIGN_ID],[MVMT_REASON],[ITEM_CODE],[QUANTITY],[ST_QUALITY],[REASON],[PROD_ORDER],
				[SUPPLIER_DDT_CODE],[RNC_NUMBER],[SUB_LOAD_ORDER_TYPE],[DOC_NUMBER],[REF_NUMBER],[RETURN_DATE],[TYPE_CODE],[SUPPLIER_CODE],
				[COMM_PROD],[COMM_SALE],[NOTES])
		VALUES
			(GETDATE(),0,NULL, UPPER(@Id_Utente), @Sign,@Causale,@CODICE_MATERIALE, @Qty,
				'DISP','','','','','','','',NULL,'','',NULL,NULL,NULL)
		
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