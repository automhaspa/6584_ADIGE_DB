SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [l3integration].[sp_Modula_Import_HostOutcomingSummary]
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
		DECLARE @ID_UDC_MODULA		INT = 702;

		DECLARE @IdArticoloAwm		INT
		DECLARE @IdUdcDettaglio		INT
		DECLARE @Id_Testata_Lista	INT
		DECLARE @Id_Riga_Lista		INT
		DECLARE @LineID				INT
		DECLARE @QtaDaPrelevare		INT
		DECLARE @IdRigaPrelievo		INT
		DECLARE @FlagFlVoid			BIT = 0;	
		DECLARE @Kit_Id				INT
		DECLARE @Msg				VARCHAR(MAX)
		DECLARE @StatoMissione		INT
		DECLARE @OrderId			NVARCHAR(20), @OrderType nvarchar(100), @ItemCode nvarchar(40), @Quantity numeric(10,2),
				@ProdOrderLineId	NVARCHAR(100), @Username varchar(32)

		--Il campo ORDER_TYPE in Modula rappresenta la causale OUT_L per le liste automha
		DECLARE CursoreOutgoingSummary CURSOR LOCAL FAST_FORWARD FOR
			SELECT	ORDER_ID,
					ORDER_TYPE,
					ITEM_CODE,
					QUANTITY,
					PROD_ORDER_LINE_ID,
					ISNULL(USERNAME, 'NON DEFINITO')
			FROM	MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_SUMMARY WITH(NOLOCK)

		OPEN CursoreOutgoingSummary
		FETCH NEXT FROM CursoreOutgoingSummary INTO
			@OrderId,
			@OrderType,
			@ItemCode,
			@Quantity,
			@ProdOrderLineId,
			@Username

		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				SET @LineID				= 0
				SET @IdArticoloAwm		= 0
				SET @IdRigaPrelievo		= 0
				SET @IdUdcDettaglio		= 0
				SET @Id_Testata_Lista	= 0
				SET @Id_Riga_Lista		= 0
				SET @QtaDaPrelevare		= 0
				SET @Kit_Id				= 0
				SET @Id_Utente			= UPPER(@Username)

				SELECT	@IdArticoloAwm = Id_Articolo
				FROM	Articoli
				WHERE	Codice = @ItemCode

				DECLARE @STL VARCHAR(max) = CONCAT('PROCESSO ARTICOLO CON CODICE: ', @ItemCode, ' DI ID: ', @IdArticoloAwm, '  ORDER ID : ', @OrderId, ' ORDER TYPE: ', @OrderType,
					' PROD ORDER LINE ID : ', @ProdOrderLineId, ' QUANTITY: ', @Quantity )

				EXEC sp_Insert_Log
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Proprieta_Log		= @Nome_StoredProcedure,
						@Id_Utente			= @Id_Utente,
						@Id_Tipo_Log		= 8,
						@Id_Tipo_Allerta	= 0,
						@Messaggio			= @STL,
						@Errore				= @Errore OUTPUT;

				--SE HO UN RISCONTRO CON UN ARTICOLO
				IF (ISNULL(@IdArticoloAwm, 0) <> 0)
				BEGIN
					--STO PROCESSANDO UNA LISTA AUTOMHA ATTIVA
					IF EXISTS	(
									SELECT	TOP 1 1
									FROM	Custom.TestataListePrelievo
									WHERE	ORDER_ID = @OrderId
										AND ORDER_TYPE = @OrderType
										AND (
												Stato IN (2,5,3)
												OR
												(Stato = 1 AND ISNULL(APERTURA_MANCANTI,0)=1)
											)
								)
					BEGIN
						--RECUPERO IL LINE ID SPLITTANDO LA STRINGA
						SELECT	@LineID = ISNULL(CAST(chunk AS INT), 0)
						FROM	SplitString(@ProdOrderLineId, '_') WHERE Passo = 2
					
						SELECT	@Kit_Id = ISNULL(CAST(chunk AS INT), 0)
						FROM	SplitString(@ProdOrderLineId, '_') WHERE Passo = 3

						--SE NON HO CORRISPONDENZA CON IL LINE_ID ???
						--Punto alla singola linea della missione Picking Dettaglio
						SELECT	@IdUdcDettaglio = Id_UdcDettaglio,
								@Id_Testata_Lista = Id_Testata_Lista,
								@Id_Riga_Lista = rlp.ID,
								@QtaDaPrelevare = Quantita,
								@StatoMissione  = mpd.Id_Stato_Missione
						FROM	Missioni_Picking_Dettaglio				mpd 
						JOIN	Custom.RigheListePrelievo				rlp ON rlp.ID = Id_Riga_Lista
						JOIN	Custom.TestataListePrelievo				tlp ON tlp.ID = Id_Testata_Lista
						WHERE	mpd.Id_Articolo = @IdArticoloAwm
							AND mpd.Id_Udc = @ID_UDC_MODULA
							AND tlp.ORDER_ID = @OrderId
							AND tlp.ORDER_TYPE = @OrderType
							AND rlp.LINE_ID = @LineID
							AND Id_Stato_Missione IN (2,3)

						--Controllo corrispondenza tra lista in uscita e situazione attuale e che non ci siano doppioni						
						--CONTROLLO SE C'E' UN RECORD DOPPIONE
						IF @Id_Testata_Lista <> 0
						BEGIN
							--SE LA QUANTITA E' A 0 E' PREVISTA LA CHIUSURA
							IF @Quantity > 0	--@Quantity >= @QtaDaPrelevare PREVISTO DOPPIO CONSUNTIVO
								SET @FlagFlVoid = 0
							ELSE
								SET @FlagFlVoid = 1

							--Sottraggo alla giacenza modula la quantità estratta
							EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
									@Id_Udc					= @ID_UDC_MODULA,
									@Id_UdcDettaglio		= @IdUdcDettaglio,
									@Id_Articolo			= @IdArticoloAwm,
									@Qta_Pezzi_Input		= @Quantity,
									@Id_Riga_Lista			= @Id_Riga_Lista,
									@Id_Testata_Lista		= @Id_Testata_Lista,
									@Id_Causale_Movimento	= 1,
									@Flag_FlVoid			= @FlagFlVoid,
									@USERNAME				= @Username,
									@Id_Processo			= @Id_Processo,
									@Origine_Log			= @Origine_Log,
									@Id_Utente				= @Id_Utente,
									@Errore					= @Errore OUTPUT

							IF ISNULL(@Errore, '') <> ''
								THROW 50001, @Errore, 1
						END
						ELSE
							THROW 50006, 'NESSUNA CORRISPONDENZA TROVATA CON UNA RIGA ATTIVA NELLE LISTE DI PRELIEVO (CONTROLLARE SE NON E'' GIA STATO PROCESSATO ED E'' UN RECORD DUPLICATO)',1

						--Controllo fine Lista
						EXEC [dbo].[sp_Update_Stati_ListePrelievo]
								@Id_Testata_Lista	= @Id_Testata_Lista,
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Id_Utente			= @Id_Utente,
								@Errore				= @Errore			OUTPUT

						IF ISNULL(@Errore, '') <> ''
							THROW 50001, @Errore, 1

						SET XACT_ABORT ON
						DELETE	MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_SUMMARY
						WHERE	ORDER_ID = @OrderId
							AND ORDER_TYPE = @OrderType
							AND ITEM_CODE = @ItemCode
							AND PROD_ORDER_LINE_ID = @ProdOrderLineId
							AND QUANTITY = @Quantity
						SET XACT_ABORT OFF

						--LOGGING ELIMINAZIONE ARTICOLO
						DECLARE @LogInfo VARCHAR(max) = CONCAT('PROCESSATO RECORD: ', @ItemCode, ' ORDER ID: ', @OrderId, ' ORDER TYPE: ', @OrderType  ,' LINE: ', @ProdOrderLineId, '  QUANTITY : ', @Quantity)
						EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 8,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @LogInfo,
							@Errore				= @Errore OUTPUT
					END
				--LO CONSIDERO COME UNA LISTA MANUALE DI PRELIEVO
				--MODIFCA NECESSARIA PER CONTROLLO DOPPIONI
					ELSE IF NOT EXISTS(SELECT TOP 1 1 FROM Custom.TestataListePrelievo WHERE ORDER_ID = @OrderId AND ORDER_TYPE = @OrderType)
						THROW 50001, 'LISTE MANUALI DA MODULA NON GESTITE',1
					ELSE
						THROW 50001, 'NESSUNA CORRISPONDENZA TROVATA CON RIGHE DI PRELIEVO ATTIVE PERCHE'' LA LISTA E'' GIA'' STATA EVASA, (CONTROLLARE SE IL RECORD E UN DUPLICATO) ',1
				END
			END TRY
			BEGIN  CATCH
				SET @Msg = CONCAT('ERRORE NEL PROCESSARE RECORD: ITEM CODE: ', @ItemCode, ' ORDER ID: ', @OrderId, ' ORDER TYPE: ', @OrderType, ' MOTIVO: ', ERROR_MESSAGE())

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
				@OrderId,
				@OrderType,
				@ItemCode,
				@Quantity,
				@ProdOrderLineId,
				@Username
		END
		
		CLOSE CursoreOutgoingSummary
		DEALLOCATE CursoreOutgoingSummary

		DECLARE @TEMPO INT = DATEDIFF(MILLISECOND,@START,GETDATE())

		IF @TEMPO> 500
		BEGIN
			DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Import Ougoing Summary Modula - TEMPO IMPIEGATO ',@TEMPO)
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
