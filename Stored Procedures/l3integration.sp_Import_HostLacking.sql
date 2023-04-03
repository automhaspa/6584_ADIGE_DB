SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





CREATE PROCEDURE [l3integration].[sp_Import_HostLacking]
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
	DECLARE @Nome_StoredProcedure	VARCHAR(100);
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
		DECLARE @Start DATETIME = GETDATE()

		-- Dichiarazioni Variabili;
		DECLARE @CursoreMovimenti	CURSOR
		DECLARE @LINE_ID			INT
		DECLARE @ID					INT
		DECLARE @IdArticoloAwm		INT
		DECLARE @Quantity			NUMERIC(10,2)
		DECLARE @USERNAME			VARCHAR(MAX)
		DECLARE @PRGMSG				INT
		DECLARE @WBS_ELEM			VARCHAR(24)
		DECLARE @COMM_PROD			VARCHAR(15)
		DECLARE @COMM_SALE			VARCHAR(25)
		DECLARE @PROD_ORDER			VARCHAR(20)
		DECLARE @SAP_DOC_NUMBER		VARCHAR(40)
		DECLARE @PROD_LINE			VARCHAR(80)
		DECLARE @FL_VOID			INT
		DECLARE @ORDER_ID			VARCHAR(40)
		DECLARE @ORDER_TYPE			VARCHAR(4)
		DECLARE @DT_EVASIONE		DATE
		DECLARE @DES_PREL_CONF		VARCHAR(18)
		
		DECLARE CursoreMovimenti CURSOR LOCAL FAST_FORWARD FOR
			SELECT	HL.PRG_MSG,
					ISNULL(tlp.ID,hl.PRG_MSG),
					HL.LINE_ID,
					A.Id_Articolo,
					HL.QUANTITY,
					UPPER(HL.USERNAME),
					CASE
						WHEN HL.SOBKZ = 'Q' THEN HL.COMM_SALE
						ELSE NULL
					END,
					CASE
						WHEN ISNULL(hl.COMM_PROD,'') = '' THEN rlp.COMM_PROD
						ELSE HL.COMM_PROD
					END,
					CASE
						WHEN ISNULL(hl.COMM_SALE,'') = '' THEN rlp.COMM_SALE
						ELSE hl.COMM_SALE
					END,
					CASE
						WHEN ISNULL(HL.ORDERS, ISNULL(hl.PROD_ORDER,'')) in ('','.') THEN ISNULL(rlp.PROD_ORDER,HL.PROD_ORDER)
						ELSE hl.PROD_ORDER
					END,
					HL.SAP_DOC_NUM,
					CASE
						WHEN ISNULL(hl.PROD_LINE,'') in ('','.') THEN ISNULL(rlp.PROD_LINE,HL.RSDEST)
						ELSE hl.PROD_LINE
					END,
					FL_VOID,
					ISNULL(HL.ORDER_ID,TLP.ORDER_ID),
					ISNULL(HL.ORDER_TYPE,TLP.ORDER_TYPE),
					ISNULL(HL.DT_EVASIONE,tlp.DT_EVASIONE),
					ISNULL(HL.RSDEST,tlp.DES_PREL_CONF)
			FROM	l3integration.dbo.HOST_LACKINGS		HL
			JOIN	Articoli							A
			ON		A.Codice = HL.ITEM_CODE
			LEFT
			JOIN	Custom.TestataListePrelievo			tlp
			ON		tlp.ORDER_ID = hl.ORDER_ID
			LEFT
			JOIN	Custom.RigheListePrelievo			rlp
			ON		rlp.Id_Testata = tlp.ID
				AND rlp.LINE_ID = HL.LINE_ID
			WHERE	status = 0
			GROUP
				BY	HL.PRG_MSG,
					tlp.ID,
					HL.LINE_ID,
					A.Id_Articolo,
					HL.QUANTITY,
					UPPER(HL.USERNAME),
					CASE WHEN HL.SOBKZ = 'Q' THEN HL.COMM_SALE ELSE NULL END,
					CASE WHEN ISNULL(hl.COMM_PROD,'') = '' THEN rlp.COMM_PROD ELSE HL.COMM_PROD END,
					CASE WHEN ISNULL(hl.COMM_SALE,'') = '' THEN rlp.COMM_SALE ELSE hl.COMM_SALE END,
					CASE
						WHEN ISNULL(HL.ORDERS, ISNULL(hl.PROD_ORDER,'')) in ('','.') THEN ISNULL(rlp.PROD_ORDER,HL.PROD_ORDER)
						ELSE hl.PROD_ORDER
					END,
					HL.SAP_DOC_NUM,
					CASE
						WHEN ISNULL(hl.PROD_LINE,'') in ('','.') THEN ISNULL(rlp.PROD_LINE,HL.RSDEST)
						ELSE hl.PROD_LINE
					END,
					FL_VOID,
					ISNULL(HL.ORDER_ID,TLP.ORDER_ID),
					ISNULL(HL.ORDER_TYPE,TLP.ORDER_TYPE),
					ISNULL(HL.DT_EVASIONE,tlp.DT_EVASIONE),
					ISNULL(HL.RSDEST,tlp.DES_PREL_CONF)
			ORDER
				BY	PRG_MSG

		OPEN CursoreMovimenti
		FETCH NEXT FROM CursoreMovimenti INTO
			@PRGMSG,
			@ID,
			@LINE_ID,
			@IdArticoloAwm,
			@Quantity,
			@Username,
			@WBS_ELEM,
			@COMM_PROD,
			@COMM_SALE,
			@PROD_ORDER,
			@SAP_DOC_NUMBER,
			@PROD_LINE,
			@FL_VOID,
			@ORDER_ID,
			@ORDER_TYPE,
			@DT_EVASIONE,
			@DES_PREL_CONF

		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				IF @FL_VOID = 2
				BEGIN
					IF NOT EXISTS (SELECT TOP(1) 1 FROM CUSTOM.AnagraficaMancanti WHERE Id_Testata = @ID AND Id_Articolo = @IdArticoloAwm AND isnull(WBS_Riferimento,'') = isnull(@WBS_ELEM,'') AND Id_Riga = @LINE_ID)
						THROW 50009, 'NON CI SONO MANCANTI DA AGGIORNARE PER L''ORDINE DEFINITO', 1

					UPDATE	Custom.AnagraficaMancanti
					SET		PROD_ORDER = @PROD_ORDER
					WHERE	Id_Testata = @ID
						AND Id_Articolo = @IdArticoloAwm
						AND ISNULL(WBS_Riferimento,'') = ISNULL(@WBS_ELEM,'')
						AND Id_Riga = @LINE_ID
				END
				ELSE
				BEGIN
					IF EXISTS(SELECT TOP 1 1 FROM CUSTOM.AnagraficaMancanti WHERE ORDER_ID = @ORDER_ID AND Id_Riga = @LINE_ID)
					BEGIN
						DECLARE @MSG_ERR VARCHAR(MAX) = CONCAT('CHIAVE DUPLICATA SAP PER ORDER ID ', @ORDER_ID, ' POSIZIONE ', @LINE_ID)
						;THROW 50009, @MSG_ERR,1
					END

					INSERT INTO Custom.AnagraficaMancanti (Id_Testata,Id_Riga,Id_Articolo,Qta_Mancante,WBS_Riferimento, COMM_PROD, COMM_SALE,PROD_ORDER,SAP_DOC_NUM, PROD_LINE,ORDER_ID,ORDER_TYPE,DT_EVASIONE, RagSoc_Dest)
					VALUES (@ID, @LINE_ID, @IdArticoloAwm, @Quantity,@WBS_ELEM,@COMM_PROD,@COMM_SALE,@PROD_ORDER,@SAP_DOC_NUMBER,@PROD_LINE,@ORDER_ID,@ORDER_TYPE,@DT_EVASIONE,@DES_PREL_CONF)
				END

				IF EXISTS (SELECT TOP(1) 1 FROM CUSTOM.TestataListePrelievo WHERE ID = @ID AND ISNULL(STATO,1) NOT IN (1,3))
					UPDATE	CUSTOM.TestataListePrelievo
					SET		STATO = 3
					WHERE	ID = @ID

				UPDATE	l3integration.dbo.HOST_LACKINGS
				SET		STATUS = 1,
						DT_ELAB = CAST(GETDATE() AS DATE)
				WHERE	PRG_MSG = @PrgMsg
			END TRY
			BEGIN CATCH
				UPDATE	l3integration.dbo.HOST_LACKINGS
				SET		STATUS = 2,
						DT_ELAB = CAST(GETDATE() AS DATE)
				WHERE	PRG_MSG = @PrgMsg

				DECLARE @Msg varchar(MAX) =  CONCAT('ERRORE NEL PROCESSARE RECORD PRG MSG:  ', @PrgMsg, ' MOTIVO: ', ERROR_MESSAGE())

				EXEC sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= @Nome_StoredProcedure,
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 4,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @Msg,
					@Errore				= @Errore OUTPUT
			END CATCH
			
			FETCH NEXT FROM CursoreMovimenti INTO
				@PRGMSG,
				@ID,
				@LINE_ID,
				@IdArticoloAwm,
				@Quantity,
				@Username,
				@WBS_ELEM,
				@COMM_PROD,
				@COMM_SALE,
				@PROD_ORDER,
				@SAP_DOC_NUMBER,
				@PROD_LINE,
				@FL_VOID,
				@ORDER_ID,
				@ORDER_TYPE,
				@DT_EVASIONE,
				@DES_PREL_CONF
		END
		
		CLOSE CursoreMovimenti
		DEALLOCATE CursoreMovimenti
		
		DECLARE @Tempo INT = DATEDIFF(MILLISECOND,@START,GETDATE())

		IF @Tempo > 500
		BEGIN
			DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Import LACKING - TEMPO IMPIEGATO ',@TEMPO)
			EXEC dbo.sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= 'Tempistiche',
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 16,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @MSG_LOG,
					@Errore				= @Errore OUTPUT;
		END

		-- Fine del codice
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
