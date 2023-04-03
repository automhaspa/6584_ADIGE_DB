SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [l3integration].[sp_Import_HostOutgoingOL]
	-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(32),
	@Errore			VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT OFF;

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(100)
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
		DECLARE @START DATETIME = GETDATE()

		-- Dichiarazioni Variabili;
		DECLARE @OrderId				VARCHAR(40)
		DECLARE @OrderType				VARCHAR(3)
		DECLARE @StatoImport			INT
		DECLARE @Prg_Msg				INT
		DECLARE @Msg					VARCHAR(MAX)
		DECLARE @Pre_Lack				VARCHAR(1)

		DECLARE @MSG_APERTURA VARCHAR(MAX)
		-- Inserimento del codice;

		--Carico gli articoli da elaborare
		DECLARE CursoreTestataListe CURSOR LOCAL FAST_FORWARD FOR
		--Primary key logica per ogni testata ordini
			SELECT	DISTINCT
					PRG_MSG,
					ORDER_ID,
					ORDER_TYPE,
					PRELACK
			FROM	L3INTEGRATION.dbo.HOST_OUTGOING_ORDERS
			WHERE	STATUS = 0
				AND FL_KIT_CALC = 0

		--Elaboro ogni Testata ordine 
		OPEN CursoreTestataListe
		FETCH NEXT FROM CursoreTestataListe INTO
			@Prg_Msg,
			@OrderId,
			@OrderType,
			@Pre_Lack
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				IF ISNULL(@Pre_Lack,'') <> 'X'
				BEGIN
					--Controllo se esiste già una testata salvata IN STATO NON CHIUSURA FORZATA
					IF EXISTS	(
									SELECT	TOP 1 1
									FROM	Custom.TestataListePrelievo tlp
									WHERE	tlp.ORDER_ID = @OrderId
										AND tlp.ORDER_TYPE = @OrderType
										AND tlp.Stato <> 6
								)
						THROW 50001, 'RECORD DI TESTATA LISTA DUPLICATO ',1

					--Inserisco nella tabella locale, uno alla volta altrimenti se ho duplicati me li inserisce tutti
					INSERT INTO Custom.TestataListePrelievo
					SELECT	TOP(1) ORDER_ID, ORDER_TYPE,DT_EVASIONE, COMM_PROD, COMM_SALE, DES_PREL_CONF, ITEM_CODE_FIN, FL_KIT, NR_KIT, PRIORITY,
									PROD_LINE, SUB_ORDER_TYPE, RAD, PFIN, DETT_ETI, FL_LABEL, FL_KIT_CALC, 1, GETDATE(), NULL,0
					FROM	L3INTEGRATION.dbo.HOST_OUTGOING_ORDERS
					WHERE	PRG_MSG = @Prg_Msg
						AND STATUS = 0
				END
				
				--Aggiorno lo stato
				UPDATE	L3INTEGRATION.dbo.HOST_OUTGOING_ORDERS
				SET		STATUS = 1,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @Prg_Msg
			END TRY
			BEGIN CATCH
				--Aggiorno lo stato
				UPDATE	L3INTEGRATION.dbo.HOST_OUTGOING_ORDERS
				SET		STATUS = 2,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @Prg_Msg

				SET @Msg = CONCAT('ERRORE NEL PROCESSARE RECORD OUTGOING ORDERS PRG_MSG: ', @Prg_MSg , ' ORDER_ID: ' , @OrderId, ' ORDER TYPE: ', @OrderType , ' MOTIVO: ' , ERROR_MESSAGE())
					
				EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 4,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @Msg,
							@Errore				= @Errore OUTPUT;
			END CATCH

			FETCH NEXT FROM CursoreTestataListe INTO
					@Prg_Msg,
					@OrderId,
					@OrderType,
					@Pre_Lack
		END

		CLOSE CursoreTestataListe
		DEALLOCATE CursoreTestataListe

		--Import linee 		
		DECLARE @LineId				INT
		DECLARE @Id_Testata			INT
		DECLARE @SAP_DOC_NUMBER		VARCHAR(50)
		DECLARE @SOBKZ				VARCHAR(1)	--> INDICA SE SI TRATTA DI UN'ESTRAZIONE LEGATA A WBS
		DECLARE @BEHMG				NUMERIC(18,2)
		DECLARE @PKBHT				VARCHAR(18)
		DECLARE @ABLAD				VARCHAR(10)
		
		--Primary key per ogni riga ordine
		DECLARE CursoreLineeListe CURSOR LOCAL FAST_FORWARD FOR
			SELECT	DISTINCT hol.PRG_MSG,
					hol.ORDER_ID,
					hol.ORDER_TYPE,
					hol.LINE_ID,
					hol.SAP_DOC_NUM,
					HOL.SOBKZ,
					HOL.BEHMG,
					HOL.PKBHT,
					HOL.ABLAD
			FROM	L3INTEGRATION.dbo.HOST_OUTGOING_LINES	hol
			JOIN	L3INTEGRATION.dbo.HOST_OUTGOING_ORDERS	hoo
			ON		hoo.ORDER_ID = hol.ORDER_ID
				AND hol.ORDER_TYPE = hoo.ORDER_TYPE
				AND hol.STATUS = 0
				AND hoo.FL_KIT_CALC = 0

		OPEN CursoreLineeListe
		FETCH NEXT FROM CursoreLineeListe INTO
			@Prg_Msg,
			@OrderId,
			@OrderType,
			@LineId,
			@SAP_DOC_NUMBER,
			@SOBKZ,
			@BEHMG,
			@PKBHT,
			@ABLAD

		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				SET @Id_Testata = NULL
				SET @MSG_APERTURA = NULL

				--CONTROLLO  SE C'E GIA UNA TESTATA IMPORTATA CHE NON SIA IN STATO ELIMINATO
				SELECT	@Id_Testata = ISNULL(ID, 0)
				FROM	Custom.TestataListePrelievo
				WHERE	ORDER_ID = @OrderId
					AND ORDER_TYPE = @OrderType
					AND Stato <> 6
					
				--Controllo di avere corrispondenza con una testata e che non ci siano duplicati
				IF	EXISTS	(
								SELECT	TOP 1 1
								FROM	Custom.RigheListePrelievo
								WHERE	Id_Testata = @Id_Testata
									AND LINE_ID = @LineId
									AND SAP_DOC_NUM = @SAP_DOC_NUMBER
							)
					THROW 50001, 'RECORD DUPLICATO',1;

				IF ISNULL(@Id_Testata,0) = 0
					THROW 50001, ' TESTATA LISTA DI PRELIEVO NON TROVATA',1;

				INSERT INTO Custom.RigheListePrelievo
					(Id_Testata,LINE_ID,LINE_ID_ERP,ITEM_CODE,PROD_ORDER,QUANTITY,COMM_PROD,COMM_SALE,PROD_LINE,DOC_NUMBER,SAP_DOC_NUM,RETURN_DATE,KIT_ID,Stato,RSPOS,WBS_Riferimento, Vincolo_WBS, Magazzino,Motivo_Nc,
						BEHMG,PKBHT,ABLAD)
				SELECT	TOP(1)
						@Id_Testata,LINE_ID, hol.LINE_ID_ERP, a.Codice, PROD_ORDER, QUANTITY, COMM_PROD, COMM_SALE, PROD_LINE, DOC_NUMBER, SAP_DOC_NUM, RETURN_DATE, KIT_ID, NULL, RSPOS, COMM_SALE,
						CASE WHEN hol.SOBKZ = 'Q' THEN 1 ELSE 0 END,
						HOL.LGORT,	-->INDICA IL MAGAZZINO --> SE 0020 ALLORA E' UN'ESTRAZIONE NON CONFORMI
						NULL,
						@BEHMG,
						@PKBHT,
						@ABLAD
				FROM	L3INTEGRATION.dbo.HOST_OUTGOING_LINES	hol
				JOIN	dbo.Articoli								A
				ON		A.Codice = hol.ITEM_CODE
				WHERE	hol.PRG_MSG = @Prg_Msg
					AND STATUS = 0

				--Se sto aggiungendo righe e la lista è già stata avviata devo rimetterla in esecuzione
				IF EXISTS	(
								SELECT	TOP 1 1
								FROM	Custom.TestataListePrelievo
								WHERE	ID = @Id_Testata
									AND Stato <> 1 --NOT IN (6,1)--,3)
							)
				BEGIN
					UPDATE	Custom.TestataListePrelievo
					SET		Stato = 1,
							APERTURA_MANCANTI = 1
					WHERE	ID = @Id_Testata

					SET @MSG_APERTURA = CONCAT('RIAPERTURA LISTA ', @ID_TESTATA)
					EXEC sp_Insert_Log
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Proprieta_Log		= @Nome_StoredProcedure,
						@Id_Utente			= @Id_Utente,
						@Id_Tipo_Log		= 4,
						@Id_Tipo_Allerta	= 0,
						@Messaggio			= @MSG_APERTURA,
						@Errore				= @Errore OUTPUT;
				END

				--Aggiorno lo stato del record
				UPDATE	L3INTEGRATION.dbo.HOST_OUTGOING_LINES
				SET		STATUS = 1,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @Prg_Msg
			END TRY
			BEGIN CATCH
				UPDATE	L3INTEGRATION.dbo.HOST_OUTGOING_LINES
				SET		STATUS = 2,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @Prg_Msg

				SET @Msg = CONCAT('ERRORE NEL PROCESSARE RECORD OUTGOING LINES PRG_MSG: ', @Prg_MSg , ' ORDER_ID: ' , @OrderId, ' ORDER TYPE: ', @OrderType , ' MOTIVO: ' , ERROR_MESSAGE())
				EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 4,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @Msg,
							@Errore				= @Errore OUTPUT;
			END CATCH

			FETCH NEXT FROM CursoreLineeListe INTO
				@Prg_Msg,
				@OrderId,
				@OrderType,
				@LineId,
				@SAP_DOC_NUMBER,
				@SOBKZ,
				@BEHMG,
				@PKBHT,
				@ABLAD
		END

		CLOSE CursoreLineeListe;
		DEALLOCATE CursoreLineeListe;

		--CONTROLLO KIT
		DECLARE	@NrKit				INT
		DECLARE @Udm				VARCHAR(3)
		DECLARE @QuantitaDivisa		NUMERIC(10,2)
		DECLARE	@Counter			INT
		
		--GESTIONE FL_KIT_CALC A 1 CON CALCOLO DA AWM
		DECLARE CursoreTestataKit CURSOR LOCAL FAST_FORWARD FOR
			SELECT	ORDER_ID,
					ORDER_TYPE,
					NR_KIT
			FROM	L3INTEGRATION.dbo.HOST_OUTGOING_ORDERS
			WHERE	STATUS = 0
				AND FL_KIT_CALC = 1

		OPEN CursoreTestataKit
		FETCH NEXT FROM CursoreTestataKit INTO
			@OrderId,
			@OrderType,
			@NrKit

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @Counter = 1

			IF (@NrKit > 6)
				THROW 50001, ' MASSIMO NUMERO DI KIT GESTIBILI SFORATO', 1

			--KIT ID = 0
			DECLARE CursoreLineeListeKit CURSOR LOCAL FAST_FORWARD FOR
				SELECT	hol.ORDER_ID,
						hol.ORDER_TYPE,
						hol.LINE_ID,
						a.Unita_Misura
				FROM	L3INTEGRATION.dbo.HOST_OUTGOING_LINES	hol
				JOIN	Articoli								a
				ON		a.Codice = hol.ITEM_CODE
				WHERE	hol.STATUS = 0
					AND hol.ORDER_ID = @OrderId
					AND hol.ORDER_TYPE = @OrderType

			--Per ogni Kit da creare
			WHILE (@Counter <= @NrKit)
			BEGIN
				--Genero le sue righe utilizzando come KIT_ID = @Counter
				OPEN CursoreLineeListeKit
				FETCH NEXT FROM CursoreLineeListeKit INTO
					@OrderId,
					@OrderType,
					@LineId,
					@Udm
					
				WHILE @@FETCH_STATUS = 0
				BEGIN
					--Quantita divisibili in qualsiasi caso con 2 gradi di precisione
					IF (@Udm IN ('MT', 'KG', 'LT'))
						SELECT	@QuantitaDivisa = hol.QUANTITY / CAST(@NrKit AS numeric(10,2))
						FROM	L3INTEGRATION.dbo.HOST_OUTGOING_LINES	hol
						WHERE	hol.STATUS = 0
							AND hol.ORDER_ID = @OrderId
							AND hol.ORDER_TYPE = @OrderType
							AND LINE_ID = @LineId
					--Effettuo una divisione intera
					ELSE IF (@Udm IN ('NR', 'PZ'))
						SELECT	@QuantitaDivisa = CAST(hol.QUANTITY / @NrKit AS int)
						FROM	L3INTEGRATION.dbo.HOST_OUTGOING_LINES hol 
						WHERE	hol.STATUS = 0
							AND hol.ORDER_ID = @OrderId
							AND hol.ORDER_TYPE = @OrderType
							AND LINE_ID = @LineId

					INSERT INTO Custom.RigheListePrelievo (Id_Testata,LINE_ID,LINE_ID_ERP,ITEM_CODE,PROD_ORDER,QUANTITY,COMM_PROD,COMM_SALE,PROD_LINE,DOC_NUMBER,SAP_DOC_NUM,RETURN_DATE,KIT_ID,Stato,RSPOS)
					SELECT	TOP(1) @Id_Testata,LINE_ID, LINE_ID_ERP,ITEM_CODE, PROD_ORDER, @QuantitaDivisa, COMM_PROD, COMM_SALE, PROD_LINE, DOC_NUMBER, SAP_DOC_NUM, RETURN_DATE, @Counter, NULL, RSPOS
					FROM	L3INTEGRATION.dbo.HOST_OUTGOING_LINES
					WHERE	ORDER_ID = @OrderId
						AND ORDER_TYPE = @OrderType
						AND LINE_ID = @LineId
						AND STATUS = 0

					FETCH NEXT FROM CursoreLineeListeKit INTO
							@OrderId,
							@OrderType,
							@LineId,
							@Udm
				END

				CLOSE CursoreLineeListeKit;
				IF (CURSOR_STATUS('local','CursoreLineeListeKit') >= -1)
					DEALLOCATE CursoreLineeListeKit

				SET @Counter = @Counter + 1
			END

			--Finita le gestione per ogni kit aggiorno lo stato riga
			--Aggiorno lo stato del record
			UPDATE	L3INTEGRATION.dbo.HOST_OUTGOING_LINES
			SET		STATUS = 1,
					DT_ELAB = GETDATE()
			WHERE	ORDER_ID = @OrderId
				AND ORDER_TYPE = @OrderType
				AND LINE_ID = @LineId

			FETCH NEXT FROM CursoreTestataKit INTO
					@OrderId,
					@OrderType,
					@NrKit
		END
		
		CLOSE CursoreTestataKit;
		
		IF (CURSOR_STATUS('local','CursoreTestataKit') >= -1)
			DEALLOCATE CursoreTestataKit
		
		DECLARE @TEMPO INT = DATEDIFF(MILLISECOND,@START,GETDATE())
		
		IF @TEMPO > 500
		BEGIN
			DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Import Outgoing Order - TEMPO IMPIEGATO ', @TEMPO)
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
