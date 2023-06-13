SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [dbo].[sp_Genera_Consuntivo_MovimentiMan]
	@IdCausaleL3			VARCHAR(5),
	@IdUdcDettaglio			INT,
	@IdCausaleMovimento		INT,
	@Quantity				NUMERIC(18,4),	
	@Flag_NonConforme		BIT				= 0,
	@Flag_ControlloQualita	BIT				= 0,
	@SUPPLIER_CODE			VARCHAR(10)		= NULL,
	@REASON					VARCHAR(4)		= NULL,
	@REF_NUMBER				VARCHAR(16)		= NULL,
	@DOC_NUMBER				VARCHAR(12)		= NULL,
	@PROD_ORDER				VARCHAR(20)		= NULL,
	@RETURN_DATE			DATE			= NULL,
	@USERNAME				VARCHAR(32)		= NULL,
	@WBS_CODE				VARCHAR(40)		= NULL,
	@NOTES					VARCHAR(150)	= NULL,
	@CONTROL_LOT			VARCHAR(40)		= NULL,
	-- Parametri Standard;
	@Id_Processo			VARCHAR(30),
	@Origine_Log			VARCHAR(25),
	@Id_Utente				VARCHAR(32),
	@Errore					VARCHAR(500) OUTPUT
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
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		IF @IdCausaleL3 NOT IN ('SMO','CMO','NOS')
		BEGIN
			DECLARE @ST_QUALITY VARCHAR(4) = CASE
												WHEN @IdCausaleL3 = 'UBL'		THEN 'QUAL'--'OK'
												WHEN @Flag_ControlloQualita = 0	THEN 'DISP'
												ELSE 'BLOC'
											END

			INSERT INTO [L3INTEGRATION].[dbo].[HOST_MOVEMENTS_SUMMARY]
				([DT_INS],[STATUS],[DT_ELAB],[USERNAME],[SIGN_ID],[MVMT_REASON],[ITEM_CODE],[QUANTITY],
					[ST_QUALITY],[REASON],[PROD_ORDER],[SUPPLIER_DDT_CODE],[RNC_NUMBER],[SUB_LOAD_ORDER_TYPE],[DOC_NUMBER],[REF_NUMBER],
					[RETURN_DATE],[TYPE_CODE],[SUPPLIER_CODE],[COMM_PROD],[COMM_SALE],[NOTES],[CONTROL_LOT],[WBS_ELEM])
			SELECT	TOP(1)
					GETDATE(),0,NULL,UPPER(ISNULL(@USERNAME, @Id_Utente)),
					--SIGN ID PER RETTIFICA?
					CASE
						WHEN @IdCausaleMovimento = 2		THEN '-'
						WHEN @IdCausaleMovimento IN (3,7)	THEN '+'
						WHEN @IdCausaleMovimento = 5		THEN ' '
					END,
					--CAUSALE MOVIMENTO L3
					@IdCausaleL3,
					A.Codice,
					@Quantity,
					@ST_QUALITY,
					ISNULL(@REASON,''),
					@PROD_ORDER,
					toe.SUPPLIER_DDT_CODE,
					'',--RNC_NUMBER
					roe.SUB_LOAD_ORDER_TYPE,
					ISNULL(@DOC_NUMBER,roe.DOC_NUMBER),
					ISNULL(@REF_NUMBER,roe.REF_NUMBER),
					@RETURN_DATE,
					--CAMPO TYPE CODE??
					'',
					ISNULL(@SUPPLIER_CODE,toe.SUPPLIER_CODE),
					NULL,
					NULL,
					ISNULL(@NOTES,UT.Codice_Udc), --CAMPO NOTES RISERVATO AL CODICE UDC SE NON DIVERSAMENTE SPECIFICATO
					@CONTROL_LOT,
					@WBS_CODE
			FROM	Udc_Dettaglio		UD
			JOIN	Articoli			A
			ON		UD.Id_Articolo = A.Id_Articolo
			JOIN	Udc_Testata			UT
			ON		UT.Id_Udc = UD.Id_Udc
			LEFT
			JOIN	Custom.TestataOrdiniEntrata toe
			ON		TOE.ID = UD.Id_Ddt_Reale
			LEFT
			JOIN	Custom.RigheOrdiniEntrata	roe
			ON		roe.Id_Testata = toe.ID
				AND roe.LOAD_LINE_ID = ud.Id_Riga_Ddt
			WHERE	Id_UdcDettaglio = @IdUdcDettaglio
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
