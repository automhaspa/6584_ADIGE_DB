SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [dbo].[sp_Genera_Consuntivo_PrelievoLista]
	@Id_Udc				INT,
	@Id_Testata_Lista	INT,
	@Id_Riga_Lista		INT,
	@Qta_Prelevata		NUMERIC(18,4),
	@Fl_Void			INT			= NULL,
	--CAMPO USERNAME
	@USERNAME			VARCHAR(32) = NULL,
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
		DECLARE @CodiceUdc			VARCHAR(20)
		DECLARE @ID_UDC_MODULA		INT = 702
		
		DECLARE @PosizioneLista		INT
		DECLARE @Id_Riga_Lista_C	INT
		DECLARE @Quantita_C			NUMERIC(18,4)
		DECLARE @qta_Consuntivo		NUMERIC(18,4)
		DECLARE @fine_ciclo			BIT = 0

		SELECT	@PosizioneLista = LINE_ID
		FROM	Custom.RigheListePrelievo
		WHERE	Id_Testata = @Id_Testata_Lista
			AND	ID = @Id_Riga_Lista

		SELECT	@CodiceUdc = Codice_Udc
		FROM	Udc_Testata
		WHERE	Id_Udc = @Id_Udc

		DECLARE	Cursore_PosizioniLista CURSOR FAST_FORWARD FOR
			SELECT	ID,
					QUANTITY
			FROM	Custom.RigheListePrelievo
			WHERE	Id_Testata = @Id_Testata_Lista
				AND LINE_ID = @PosizioneLista
			ORDER
				BY	QUANTITY

		OPEN Cursore_PosizioniLista
		FETCH NEXT FROM Cursore_PosizioniLista INTO
			@Id_Riga_Lista_C,
			@Quantita_C

		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @Qta_Prelevata > @Quantita_C
			BEGIN
				SET @qta_Consuntivo = @Quantita_C
				SET @Qta_Prelevata -= @qta_Consuntivo
			END
			ELSE
			BEGIN
				SET @qta_Consuntivo = @Qta_Prelevata
				SET @fine_ciclo = 1
			END

			--SCRITTURA TABELLA DI FORNTIERA
			INSERT INTO [L3INTEGRATION].[dbo].[HOST_OUTGOING_SUMMARY]
				([DT_INS],[STATUS],[DT_ELAB],[USERNAME],[ORDER_ID],[ORDER_TYPE],[DT_EVASIONE],[COMM_PROD],[COMM_SALE],[DES_PREL_CONF],[ITEM_CODE_FIN],[FL_KIT],[NR_KIT],[PRIORITY],
					[PROD_LINE],[LINE_ID],[LINE_ID_ERP],[ITEM_CODE],[PROD_ORDER],[QUANTITY],[ACTUAL_QUANTITY],[FL_VOID],[SUB_ORDER_TYPE],
					[RAD],[PFIN],[DOC_NUMBER],[RETURN_DATE],[NOTES],[SAP_DOC_NUM],[KIT_ID],[ID_UDC],[RSPOS],[SOBKZ])
			SELECT	TOP(1)
					GETDATE(), 0,NULL, UPPER(ISNULL(@USERNAME, @Id_Utente)), tlp.ORDER_ID, tlp.ORDER_TYPE, ISNULL(tlp.DT_EVASIONE, ' '),
					CASE
						WHEN ISNULL(tlp.COMM_PROD, '') = '' THEN rlp.COMM_PROD
						ELSE tlp.COMM_PROD
					END,
					CASE
						WHEN ISNULL(tlp.COMM_SALE, '') = '' THEN rlp.COMM_SALE
						ELSE tlp.COMM_SALE
					END,
					tlp.DES_PREL_CONF,tlp.ITEM_CODE_FIN,0,tlp.NR_KIT,tlp.PRIORITY,rlp.PROD_LINE,
					rlp.LINE_ID, rlp.LINE_ID_ERP,rlp.ITEM_CODE, rlp.PROD_ORDER,rlp.QUANTITY,
					@qta_Consuntivo,
					CASE
						WHEN @Fl_Void IS NOT NULL THEN @Fl_Void
						WHEN @Fl_Void IS NULL AND @Qta_Prelevata = 0 AND @Id_Udc =  @ID_UDC_MODULA THEN 1
						ELSE 0
					END,
					tlp.SUB_ORDER_TYPE, tlp.RAD, tlp.PFIN,rlp.DOC_NUMBER,rlp.RETURN_DATE, 
					@CodiceUdc, --CAMPO NOTES CONTENENTE CODICE UDC 
					rlp.SAP_DOC_NUM, rlp.KIT_ID, ' ',rlp.RSPOS,
					CASE
						WHEN ISNULL(rlp.Vincolo_WBS,0) = 1 THEN 'Q'
						ELSE ''
					END
			FROM	Custom.TestataListePrelievo		tlp
			JOIN	Custom.RigheListePrelievo		rlp
				ON	rlp.Id_Testata = tlp.ID
			WHERE	tlp.ID = @Id_Testata_Lista
				AND rlp.ID = @Id_Riga_Lista_C

			IF @fine_ciclo = 1
				BREAK;

			FETCH NEXT FROM Cursore_PosizioniLista INTO
				@Id_Riga_Lista_C,
				@Quantita_C
		END

		CLOSE Cursore_PosizioniLista
		DEALLOCATE Cursore_PosizioniLista

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
