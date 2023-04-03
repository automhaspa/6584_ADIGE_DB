SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[sp_Chiudi_Lista_Prelievo]
	--ID testata
	@ID				INT				= NULL,
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
		DECLARE @Stato	INT

		IF ISNULL(@ID,0) = 0
			THROW 50005, 'LISTA NON DEFINITA',1

		SELECT	@Stato = Stato
		FROM	Custom.TestataListePrelievo
		WHERE	ID = @ID

		--Posso eliminare liste non ancora avviate o già concluse 
		IF @Stato <> 1
			THROW 50006, 'E'' POSSIBILE FORZARE LA CHIUSURA SOLO DI UNA LISTA ANCORA NON AVVIATA',1

		--CONSUNTIVO L3
		INSERT INTO [L3INTEGRATION].[dbo].[HOST_OUTGOING_SUMMARY]
			([DT_INS],[STATUS],[DT_ELAB],[USERNAME],[ORDER_ID],[ORDER_TYPE],[DT_EVASIONE],
				[COMM_PROD],[COMM_SALE],[DES_PREL_CONF],[ITEM_CODE_FIN],[FL_KIT],[NR_KIT],[PRIORITY],[PROD_LINE],
				[LINE_ID],[LINE_ID_ERP],[ITEM_CODE],[PROD_ORDER],[QUANTITY],[ACTUAL_QUANTITY],[FL_VOID],[SUB_ORDER_TYPE],
				[RAD],[PFIN],[DOC_NUMBER],[RETURN_DATE],[NOTES],[SAP_DOC_NUM],[KIT_ID],[ID_UDC],[RSPOS])
		SELECT	GETDATE(),0, NULL, UPPER(@Id_Utente), tlp.ORDER_ID, tlp.ORDER_TYPE, ISNULL(tlp.DT_EVASIONE, ' '),
				CASE
					WHEN ISNULL(tlp.COMM_PROD, '') = '' THEN rlp.COMM_PROD
					ELSE tlp.COMM_PROD
				END,
				CASE
					WHEN ISNULL(tlp.COMM_SALE, '') = '' THEN rlp.COMM_SALE
					ELSE tlp.COMM_SALE
				END,
				tlp.DES_PREL_CONF, tlp.ITEM_CODE_FIN, 0, tlp.NR_KIT, tlp.PRIORITY, rlp.PROD_LINE,
				rlp.LINE_ID,rlp.LINE_ID_ERP, rlp.ITEM_CODE, rlp.PROD_ORDER, 
				rlp.QUANTITY, 0,1, tlp.SUB_ORDER_TYPE, tlp.RAD, tlp.PFIN, rlp.DOC_NUMBER, rlp.RETURN_DATE,
				NULL, rlp.SAP_DOC_NUM, 1, '',rlp.RSPOS
		FROM	Custom.RigheListePrelievo		rlp
		JOIN	Custom.TestataListePrelievo		tlp
		ON		rlp.Id_Testata = tlp.ID
		WHERE	tlp.ID = @ID
		
		--Aggiorno la test
		DELETE	Custom.RigheListePrelievo
		WHERE	Id_Testata = @ID
		
		DELETE	Custom.TestataListePrelievo
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
