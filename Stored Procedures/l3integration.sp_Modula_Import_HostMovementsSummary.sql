SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE PROCEDURE [l3integration].[sp_Modula_Import_HostMovementsSummary]
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
		DECLARE @START DATETIME = GETDATE()

		-- Dichiarazioni Variabili;
		DECLARE @ID_UDC_MODULA		INT = 702
		DECLARE @IdArticoloAwm		INT
		DECLARE @ITEM_CODE			VARCHAR(MAX)
		DECLARE @IdUdcDettaglio		INT
		DECLARE @PrgMsg int, @ItemCode nvarchar(40), @Quantity numeric(10,2), @Reason nvarchar(10), @ActionCausale varchar(1), @Username varchar(30)

		DECLARE CursoreMovimenti CURSOR LOCAL FAST_FORWARD FOR
			SELECT	hms.PRG_MSG,
					ISNULL(a.Id_Articolo,0),
					HMS.ITEM_CODE,
					hms.QUANTITY,
					hms.REASON,
					ISNULL(hms.USERNAME, 'NON DEFINITO')
			FROM	MODULA.HOST_IMPEXP.dbo.HOST_MOVEMENT_SUMMARY hms WITH(NOLOCK)
			LEFT
			JOIN	Articoli	a
			ON		a.Codice = hms.ITEM_CODE
			ORDER
				BY	PRG_MSG

		OPEN CursoreMovimenti
		FETCH NEXT FROM CursoreMovimenti INTO
			@PrgMsg,
			@IdArticoloAwm,
			@ITEM_CODE,
			@Quantity,
			@Reason,
			@Username
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				SET @Id_Utente = @Username
				SET @IdUdcDettaglio = NULL
				SET @ActionCausale = NULL

				IF (@IdArticoloAwm = 0)
				BEGIN
					DECLARE @MSG_ART VARCHAR(MAX) = CONCAT('Codice articolo di Modula ',@ITEM_CODE,' non presente in Automha AWM')
					;THROW 50004, @MSG_ART,1
				END

				IF @Reason IN ('CTC','RPM')
				BEGIN
					DECLARE @LogCambio_Reason VARCHAR(max) = CONCAT('CAMBIO REASON PRG_MSG: ', @PrgMsg,' CAUSALE : ', @Reason, '  QUANTITY : ', @Quantity)
					EXEC sp_Insert_Log
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Proprieta_Log		= @Nome_StoredProcedure,
						@Id_Utente			= @Id_Utente,
						@Id_Tipo_Log		= 8,
						@Id_Tipo_Allerta	= 0,
						@Messaggio			= @LogCambio_Reason,
						@Errore				= @Errore OUTPUT;
				
					IF @Reason = 'CTC'
						SET @Reason = 'RRA'
					
					IF @Reason = 'RPM'
						SET @Reason = 'RPO'
				END

				PRINT CONCAT('PROCESSO ARTICOLO ID ', @IdArticoloAwm, ' CON CAUSALE : ', @reason, ' PRG_MSG', @PrgMsg, '  QUANTITA :  ', @Quantity);
				--RECUPERO LA ACTION DELLA CAUSALE PER CAPIRE DI CHE MOVIMENTO SI TRATTA
				SELECT	@ActionCausale = Action
				FROM	Custom.CausaliMovimentazione
				WHERE	Id_Causale = @Reason

				--Controllo se ho già una quantità registrata
				SELECT	@IdUdcDettaglio = Id_UdcDettaglio
				FROM	Udc_Dettaglio
				WHERE	Id_Articolo = @IdArticoloAwm
					AND Id_Udc = @ID_UDC_MODULA
				
				PRINT CONCAT(' ACTION CAUSALE : ' , @ActionCausale)
				
				IF (ISNULL(@ActionCausale, '') = '')
					THROW 50003, ' CAUSALE NON DEFINITA PER IL CAMPO REASON DEFINITO DA OPERATORE' ,1;				
				ELSE IF (@ActionCausale = '+')
				BEGIN
					--Creo l'articolo nella UdcDettaglio Modula con causale movimento 3
					EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc	
										@Id_Udc = @ID_UDC_MODULA,
										@Id_Causale = @Reason,
										@Id_UdcDettaglio = @IdUdcDettaglio, 
										@Id_Articolo = @IdArticoloAwm,
										@Qta_Pezzi_Input = @Quantity,
										@Id_Causale_Movimento = 3,
										@Id_Processo = @Id_Processo,
										@Origine_Log = @Origine_Log,
										@Id_Utente = @Id_Utente,
										@Errore = @Errore OUTPUT
					
					IF (ISNULL(@Errore, '') <> '')
						THROW 50001, @Errore, 1
					
					PRINT ('PROCESSATO CORRETTAMENTE')
				END
				--Uscita manuale
				ELSE IF (@ActionCausale = '-')
				BEGIN
					PRINT ('UPDATE IN CORSO')
					--Eccezione nel caso in cui ho un uscita manuale di un articolo non salvato in Awm Modula
					IF (@IdUdcDettaglio IS NULL)
						THROW 50006, 'USCITA MANUALE DI UN ARTICOLO NON PRESENTE IN UDC DETTAGLIO MODULA',1;
					ELSE
					BEGIN 
						--Sottraggo le quantità dalla dettaglio
						EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc	
										@Id_Udc = @ID_UDC_MODULA,
										@Id_Causale = @Reason,
										@Id_UdcDettaglio = @IdUdcDettaglio, 
										@Id_Articolo = @IdArticoloAwm,
										@Qta_Pezzi_Input = @Quantity,
										@Id_Causale_Movimento = 2,
										@Id_Processo = @Id_Processo,
										@Origine_Log = @Origine_Log,
										@Id_Utente = @Id_Utente,
										@Errore = @Errore OUTPUT
						IF (ISNULL(@Errore, '') <> '')
							THROW 50001, @Errore, 1
						PRINT (@Errore)
					END
				END
				
				SET XACT_ABORT ON
				DELETE	MODULA.HOST_IMPEXP.dbo.HOST_MOVEMENT_SUMMARY
				WHERE	PRG_MSG = @PrgMsg
				SET XACT_ABORT OFF
				--LOGGING ELIMINAZIONE ARTICOLO 
				DECLARE @LogInfo VARCHAR(max) = CONCAT('PROCESSATO RECORD PRG_MSG: ', @PrgMsg,' ID ARTICOLO: ', @IdArticoloAwm, ' CAUSALE : ', @Reason, '  QUANTITY : ', @Quantity)
				EXEC sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= @Nome_StoredProcedure,
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 8,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @LogInfo,
					@Errore				= @Errore OUTPUT;
			END TRY
			BEGIN CATCH
				DECLARE @Msg varchar(MAX) =  CONCAT('ERRORE NEL PROCESSARE RECORD PRG MSG:  ', @PrgMsg,' CAUSALE : ', @Reason, ' MOTIVO: ', ERROR_MESSAGE())
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
			FETCH NEXT FROM CursoreMovimenti INTO 
				@PrgMsg,
				@IdArticoloAwm,
				@ITEM_CODE,
				@Quantity, 
				@Reason,
				@Username
		END

		CLOSE CursoreMovimenti
		DEALLOCATE CursoreMovimenti

		DECLARE @TEMPO INT = DATEDIFF(MILLISECOND,@START,GETDATE())

		IF @TEMPO > 500
		BEGIN
			DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Import Movements Summary Modula - TEMPO IMPIEGATO ',@TEMPO)
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
