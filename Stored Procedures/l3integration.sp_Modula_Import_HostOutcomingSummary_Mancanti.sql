SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [l3integration].[sp_Modula_Import_HostOutcomingSummary_Mancanti]
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

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata; SELECT * FROM MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_SUMMARY
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		DECLARE @START DATETIME = GETDATE()

		-- Dichiarazioni Variabili;
		DECLARE @Id_UdcDettaglio	INT
		DECLARE @Id_Testata_Lista	INT
		DECLARE @Id_Riga_Lista		INT
		DECLARE @Qta_Da_Prelevare	INT
		DECLARE @Kit_Id				INT
		DECLARE @Msg				VARCHAR(MAX)

		DECLARE @Id_Articolo_C		INT
		DECLARE @OrderId_C			NVARCHAR(20)
		DECLARE @OrderType_C		NVARCHAR(100)
		DECLARE @ItemCode_C			NVARCHAR(40)
		DECLARE @Quantity_C			NUMERIC(10,2)
		DECLARE @ProdOrderLineId_C	NVARCHAR(100)
		DECLARE @Username_C			VARCHAR(32)

		--Il campo ORDER_TYPE in Modula rappresenta la causale OUT_L per le liste automha
		DECLARE CursoreOutgoingSummary CURSOR LOCAL FAST_FORWARD FOR
			SELECT	ORDER_ID,
					ORDER_TYPE,
					ITEM_CODE,
					A.Id_Articolo,
					QUANTITY,
					PROD_ORDER_LINE_ID,
					ISNULL(USERNAME, 'NON DEFINITO')
			FROM	MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_SUMMARY	HOS
			JOIN	Articoli										A
			ON		A.Codice = HOS.ITEM_CODE
				AND HOS.QUANTITY > 0

		OPEN CursoreOutgoingSummary
		FETCH NEXT FROM CursoreOutgoingSummary INTO
			@OrderId_C,
			@OrderType_C,
			@ItemCode_C,
			@Id_Articolo_C,
			@Quantity_C,
			@ProdOrderLineId_C,
			@Username_C

		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				SET @Id_UdcDettaglio	= 0
				SET @Id_Testata_Lista	= 0
				SET @Id_Riga_Lista		= 0
				SET @Qta_Da_Prelevare	= 0
				SET @Kit_Id				= 0

				DECLARE @STL VARCHAR(max) = CONCAT('PROCESSO ARTICOLO MANCANTE CON CODICE: ', @ItemCode_C, ' ORDER ID : ', @OrderId_C, ' ORDER TYPE: ', @OrderType_C,
													' PROD ORDER LINE ID : ', @ProdOrderLineId_C, ' QUANTITY: ', @Quantity_C)
				EXEC sp_Insert_Log
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Proprieta_Log		= @Nome_StoredProcedure,
						@Id_Utente			= @Id_Utente,
						@Id_Tipo_Log		= 8,
						@Id_Tipo_Allerta	= 0,
						@Messaggio			= @STL,
						@Errore				= @Errore OUTPUT;

				SELECT	@Id_Testata_Lista = MPD.Id_Testata_Lista
				FROM	Missioni_Picking_Dettaglio		MPD
				JOIN	Custom.AnagraficaMancanti		AM
				ON		AM.Id_Articolo = MPD.Id_Articolo
					AND AM.Id_Testata = MPD.Id_Testata_Lista
					AND AM.Id_Riga = MPD.Id_Riga_Lista
				LEFT
				JOIN	Custom.TestataListePrelievo		TLP
				ON		TLP.ID = AM.Id_Testata
				WHERE	ISNULL(AM.ORDER_ID,TLP.ORDER_ID) = @OrderId_C
					AND ISNULL(AM.ORDER_TYPE,TLP.ORDER_TYPE) = @OrderType_C
					AND MPD.Id_Stato_Missione = 2
					AND MPD.Id_Udc = 702
					AND MPD.Id_Articolo = @Id_Articolo_C
					AND ISNULL(MPD.FL_MANCANTI,0) = 1

				--STO PROCESSANDO UNA LISTA AUTOMHA
				IF ISNULL(@Id_Testata_Lista,0) <> 0
				BEGIN
					--RECUPERO IL LINE ID SPLITTANDO LA STRINGA
					SELECT	@Id_Riga_Lista = ISNULL(CAST(chunk AS INT), 0)
					FROM	SplitString(@ProdOrderLineId_C, '_')
					WHERE	Passo = 2

					SELECT	@Kit_Id = ISNULL(CAST(chunk AS INT), 0)
					FROM	SplitString(@ProdOrderLineId_C, '_') WHERE Passo = 3

					--Punto alla singola linea della missione Picking Dettaglio
					SELECT	@Id_UdcDettaglio = Id_UdcDettaglio,
							@Id_Testata_Lista = Id_Testata_Lista,
							@Id_Riga_Lista = Id_Riga_Lista,
							@Qta_Da_Prelevare = Quantita
					FROM	Missioni_Picking_Dettaglio
					WHERE	Id_Articolo = @Id_Articolo_C
						AND Id_Udc = 702
						AND Id_Riga_Lista = @ID_RIGA_LISTA
						AND ID_TESTATA_LISTA = @ID_TESTATA_LISTA
						AND Id_Stato_Missione = 2
						AND ISNULL(FL_MANCANTI,0) = 1

					--Controllo corrispondenza tra lista in uscita e situazione attuale e che non ci siano doppioni
					IF @ID_UDCDETTAGLIO <> 0
					BEGIN
						--Sottraggo alla giacenza modula la quantità estratta
						EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
								@Id_Udc					= 702,
								@Id_UdcDettaglio		= @Id_UdcDettaglio,
								@Id_Articolo			= @Id_Articolo_C,
								@Qta_Pezzi_Input		= @Quantity_C,
								@Id_Riga_Lista			= @Id_Riga_Lista,
								@Id_Testata_Lista		= @Id_Testata_Lista,
								@Id_Causale_Movimento	= 1,
								@Flag_FlVoid			= 0,
								@USERNAME				= @Username_C,
								@Id_Processo			= @Id_Processo,
								@Origine_Log			= @Origine_Log,
								@Id_Utente				= @Id_Utente,
								@Errore					= @Errore OUTPUT
						
						IF (ISNULL(@Errore, '') <> '')
							THROW 50001, @Errore, 1

						--Aggiorno la tabella Mancanti
						UPDATE	Custom.AnagraficaMancanti
						SET		Qta_Mancante = Qta_Mancante - @Quantity_C
						WHERE	Id_Testata = @Id_Testata_Lista
							AND Id_Riga = @Id_Riga_Lista

						UPDATE	Missioni_Picking_Dettaglio
						SET		Id_Stato_Missione =	CASE
														WHEN Quantita = (Qta_Prelevata + @Quantity_C) THEN 4
														ELSE Id_Stato_Missione
													END,
								Qta_Prelevata += @Quantity_C,
								DataOra_UltimaModifica = GETDATE(),
								DataOra_Evasione =	CASE
														WHEN Quantita = (Qta_Prelevata + @Quantity_C) THEN GETDATE()
														ELSE DataOra_Evasione
													END
						WHERE	Id_Testata_Lista = @Id_Testata_Lista
							AND Id_Riga_Lista = @Id_Riga_Lista
							AND ISNULL(FL_MANCANTI,0) = 1
							AND Id_Stato_Missione = 2
					END
					ELSE
						THROW 50006, 'NESSUNA CORRISPONDENZA TROVATA CON UNA RIGA ATTIVA NELLE LISTE DI PRELIEVO (CONTROLLARE SE NON E'' GIA STATO PRCESSATO ED E'' UN RECORD DUPLICATO)',1;
						
					SET XACT_ABORT ON
					DELETE	MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_SUMMARY
					WHERE	ORDER_ID = @OrderId_C
						AND ORDER_TYPE = @OrderType_C
						AND ITEM_CODE = @ItemCode_C
						AND PROD_ORDER_LINE_ID = @ProdOrderLineId_C
						AND QUANTITY = @Quantity_C
					SET XACT_ABORT OFF

					DECLARE @LogInfo VARCHAR(max) = CONCAT('PROCESSATO RECORD: ', @ItemCode_C, ' ORDER ID: ', @OrderId_C, ' ORDER TYPE: ', @OrderType_C,' LINE: ', @ProdOrderLineId_C, '  QUANTITY : ', @Quantity_C)
					EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 8,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @LogInfo,
							@Errore				= @Errore OUTPUT;
			END

				ELSE
					THROW 50001, 'NESSUNA CORRISPONDENZA TROVATA CON RIGHE DI PRELIEVO MANCANTI ATTIVE (CONTROLLARE SE IL RECORD E UN DUPLICATO) ',1
			END TRY
			BEGIN  CATCH
				SET @Msg = CONCAT('ERRORE NEL PROCESSARE RECORD: ITEM CODE: ', @ItemCode_C, ' ORDER ID: ', @OrderId_C, ' ORDER TYPE: ', @OrderType_C, ' MOTIVO: ', ERROR_MESSAGE())

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

			FETCH NEXT FROM CursoreOutgoingSummary INTO
				@OrderId_C,
				@OrderType_C,
				@ItemCode_C,
				@Id_Articolo_C,
				@Quantity_C,
				@ProdOrderLineId_C,
				@Username_C
		END
		
		CLOSE CursoreOutgoingSummary
		DEALLOCATE CursoreOutgoingSummary

		DECLARE @TEMPO INT = DATEDIFF(MILLISECOND,@START,GETDATE())

		IF @TEMPO> 500
		BEGIN
			DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Import Ougoing Summary Modula Mancanti - TEMPO IMPIEGATO ',@TEMPO)
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
					@Messaggio			= 'TRANSACTION ROLLBACK',
					@Errore				= @Errore OUTPUT;
			
				-- Return 1 se la procedura è andata in errore;
				RETURN 1;
			END
		ELSE
			THROW;
	END CATCH;
END

GO
