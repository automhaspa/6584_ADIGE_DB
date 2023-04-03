SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [l3integration].[sp_Import_HostIncomingOL]
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
	--ORDINI DI ENTRATA MERCE
	BEGIN TRY
		DECLARE @START DATETIME = GETDATE()

		-- Dichiarazioni Variabili;
		DECLARE @LoadOrderId	VARCHAR(40)
		DECLARE @LoadOrderType	VARCHAR(4)
		DECLARE @LoadLineId		INT
		DECLARE @LogInfo		VARCHAR(MAX)

		-- Inserimento del codice;
		DECLARE @IdTestata	INT
		DECLARE @Prg_Msg	INT

		--Carico le testate di ordini in entrata da elaborare ordinate dal primo inserito
		DECLARE	CursoreTestata CURSOR LOCAL FAST_FORWARD FOR
			SELECT	PRG_MSG,
					LOAD_ORDER_ID,
					LOAD_ORDER_TYPE
			FROM	L3INTEGRATION.dbo.HOST_INCOMING_ORDERS
			WHERE	STATUS = 0
				AND LOAD_ORDER_TYPE NOT IN ('NWBS','CWBS','DWBS')
			ORDER
				BY	PRG_MSG ASC

		--Scorro le testate 
		OPEN CursoreTestata
		FETCH NEXT FROM CursoreTestata INTO
			@Prg_Msg,
			@LoadOrderId,
			@LoadOrderType

		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				SET @IdTestata = 0

				--Controllo se non è già presente un Ddt reale già associato a quel codice fake
				IF EXISTS	(
								SELECT	TOP 1 1
								FROM	Custom.TestataOrdiniEntrata
								WHERE	LOAD_ORDER_ID = @LoadOrderId
									AND LOAD_ORDER_TYPE = @LoadOrderType
									AND Stato <> 4
							)
					THROW 50001, ' RECORD TESTATA DDT DUPLICATO CON UNA TESTATA GIA'' PRESENTE', 1

				--Inserisco già l'Id DDT
				INSERT INTO Custom.TestataOrdiniEntrata
					(LOAD_ORDER_ID,LOAD_ORDER_TYPE,DT_RECEIVE_BLM,SUPPLIER_CODE, DES_SUPPLIER_CODE, SUPPLIER_DDT_CODE, Id_Ddt_Fittizio, Stato)
				SELECT	TOP(1)
						hiotable.LOAD_ORDER_ID, hiotable.LOAD_ORDER_TYPE, hiotable.DT_RECEIVE, hiotable.SUPPLIER_CODE,
						hiotable.DES_SUPPLIER_CODE, hiotable.SUPPLIER_DDT_CODE, adf.ID, 1
				FROM	L3INTEGRATION.dbo.HOST_INCOMING_ORDERS		hiotable
				JOIN	Custom.AnagraficaDdtFittizi					adf
				ON		adf.Codice_DDT = hiotable.AWM_LOAD_BILL_ID
				WHERE	PRG_MSG = @Prg_Msg

				--Se non ho inserito nulla (non ho corrispondenza di con il Ddt fittizio)
				IF @@ROWCOUNT = 0
					THROW 50002, 'NESSUNA CORRISPONDENZA CON UN CODICE DDT FITTIZIO ',1

				SET @IdTestata = SCOPE_IDENTITY()

				--Aggiorno stato record della testata  di scambio
				UPDATE	L3INTEGRATION.dbo.HOST_INCOMING_ORDERS
				SET		STATUS = 1,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @Prg_Msg
			END TRY
			BEGIN CATCH
				UPDATE	L3INTEGRATION.dbo.HOST_INCOMING_ORDERS
				SET		STATUS = 2,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @Prg_Msg

				SET @LogInfo = CONCAT('ERRORE NEL PROCESSARE RECORD INCOMING ORDERS PRG_MSG: ', @Prg_Msg,' LOAD ORDER ID: ', @LoadOrderId,
										' LOAD ORDER TYPE : ', @LoadOrderType, '  MOTIVO: ' , ERROR_MESSAGE())

				EXEC sp_Insert_Log
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Proprieta_Log		= @Nome_StoredProcedure,
						@Id_Utente			= @Id_Utente,
						@Id_Tipo_Log		= 4,
						@Id_Tipo_Allerta	= 0,
						@Messaggio			= @LogInfo,
						@Errore				= @Errore OUTPUT
			END CATCH

			FETCH NEXT FROM CursoreTestata INTO
				@Prg_Msg,
				@LoadOrderId,
				@LoadOrderType
		END

		CLOSE CursoreTestata
		DEALLOCATE CursoreTestata

		--PROCESSO LE RIGHE
		DECLARE @Id_Articolo	INT
		DECLARE @IdTestataRiga	INT

		--Per ogni testata recupero le righe non ancora elaborate accomunate da stesso LOAD_ORDER_TYPE e LOAD_ORDER_ID
		DECLARE CursoreRighe CURSOR LOCAL FAST_FORWARD FOR
			SELECT	hil.PRG_MSG,
					hil.LOAD_ORDER_ID,
					hil.LOAD_ORDER_TYPE,
					hil.LOAD_LINE_ID,
					A.Id_Articolo
			FROM	L3INTEGRATION.dbo.HOST_INCOMING_LINES	hil
			JOIN	Articoli								A
			ON		A.Codice = hil.ITEM_CODE
			WHERE	hil.STATUS = 0
				AND LOAD_ORDER_TYPE NOT IN ('NWBS','CWBS','DWBS')
			ORDER
				BY	LOAD_ORDER_ID,
					LOAD_LINE_ID

		--Scorro le Righe
		OPEN CursoreRighe
		FETCH NEXT FROM CursoreRighe INTO
			@Prg_Msg,
			@LoadOrderId,
			@LoadOrderType,
			@LoadLineId,
			@Id_Articolo

		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				SET @IdTestataRiga = 0

				--Se è codificato inserisco la riga
				SELECT	@IdTestataRiga = ID
				FROM	Custom.TestataOrdiniEntrata
				WHERE	LOAD_ORDER_ID = @LoadOrderId
					AND LOAD_ORDER_TYPE = @LoadOrderType
					AND Stato IN (1,2)

				IF @Id_Articolo <> 0 AND @IdTestataRiga <> 0
				BEGIN
					IF EXISTS(SELECT TOP 1 1 FROM Custom.RigheOrdiniEntrata WHERE LOAD_LINE_ID = @LoadLineId AND Id_Testata = @IdTestataRiga)
						THROW 50001, 'RECORD DUPLICATO', 1

					INSERT INTO Custom.RigheOrdiniEntrata
						(Id_Testata,LOAD_LINE_ID,ITEM_CODE,LINE_ID_ERP,QUANTITY,PURCHASE_ORDER_ID,
							FL_INDEX_ALIGN,FL_QUALITY_CHECK,COMM_PROD,COMM_SALE,SUB_LOAD_ORDER_TYPE,MANUFACTURER_ITEM,
							MANUFACTURER_NAME,DOC_NUMBER,REF_NUMBER,NOTES,CONTROL_LOT,Stato, WBS_ELEM)
					SELECT	TOP (1)
							@IdTestataRiga, LOAD_LINE_ID, ITEM_CODE, LINE_ID_ERP, QUANTITY, ISNULL(PURCHASE_ORDER_ID,''),
							FL_INDEX_ALIGN, FL_QUALITY_CHECK, COMM_PROD,
							COMM_SALE, SUB_LOAD_ORDER_TYPE, MANUFACTURER_ITEM, MANUFACTURER_NAME, DOC_NUMBER, REF_NUMBER, NOTES, CONTROL_LOT, 1, WBS_ELEM
					FROM	L3INTEGRATION.dbo.HOST_INCOMING_LINES
					WHERE	PRG_MSG = @Prg_Msg

					--Aggiorno stato record nella tabella di scambio
					UPDATE	L3INTEGRATION.dbo.HOST_INCOMING_LINES
					SET		STATUS = 1,
							DT_ELAB = GETDATE()
					WHERE	PRG_MSG = @Prg_Msg
				END
				ELSE
				BEGIN
					DECLARE @ERROR_LOG VARCHAR(MAX) = CONCAT(' TESTATA DDT NON DEFINITA PER LA RIGA ELABORATA O DDT GIA'' SPECIALIZZATO COMPLETAMENTE ', @PRG_MSG)
					;THROW 50001, @ERROR_LOG,1;
				END
			END TRY
			BEGIN CATCH
				UPDATE	L3INTEGRATION.dbo.HOST_INCOMING_LINES
				SET		STATUS = 2,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @Prg_Msg
					
				PRINT CONCAT('ERRORE NEL PROCESSARE RECORD INCOMING LINES PRG_MSG: ', @Prg_Msg,' LOAD ORDER ID: ', @LoadOrderId, ' LOAD ORDER TYPE : ', @LoadOrderType, '  MOTIVO: ' , ERROR_MESSAGE())

				SET @LogInfo = CONCAT('ERRORE NEL PROCESSARE RECORD INCOMING LINES PRG_MSG: ', @Prg_Msg,' LOAD ORDER ID: ', @LoadOrderId, ' LOAD ORDER TYPE : ', @LoadOrderType, '  MOTIVO: ' , ERROR_MESSAGE())
				EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 4,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @LogInfo,
							@Errore				= @Errore			OUTPUT
			END CATCH

			FETCH NEXT FROM CursoreRighe INTO
				@Prg_Msg,
				@LoadOrderId,
				@LoadOrderType,
				@LoadLineId,
				@Id_Articolo
		END

		CLOSE CursoreRighe
		DEALLOCATE CursoreRighe

		DECLARE @Tempo INT = DATEDIFF(MILLISECOND,@START,GETDATE())

		IF @Tempo > 500
		BEGIN
			DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Import Incoming Order - TEMPO IMPIEGATO ',@Tempo)
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
