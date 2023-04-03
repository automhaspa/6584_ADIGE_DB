SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [l3integration].[sp_Update_HostStockSummary]
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
		DECLARE	@ID_UDC_MODULA		INT = 702

		-- Inserimento del codice;
		DECLARE	@COUNTELIMINA		INT
		DECLARE @CountDettaglio		INT

		SELECT	@COUNTELIMINA = COUNT(1) FROM [l3integration].[vArticoliModulaSincro] WHERE flag_elimina = 1
		SELECT	@CountDettaglio = COUNT(1) FROM Udc_Dettaglio WHERE id_udc = 702

		IF @COUNTELIMINA >= @CountDettaglio
			THROW 50005, 'QUADRATURA GIACENZA DI MODULA NON ATTIVATA', 1

		--Quadratura della HOST_STOCK_SUMMARY di Modula con la nostra Udc_Dettaglio
		DECLARE @CodiceArticolo			VARCHAR(MAX)
		DECLARE @IdArticoloAwm			INT
		DECLARE @FlagElimina			INT
		DECLARE @IdUdcDettaglio			INT

		DECLARE @GiacenzaArticoloModula		NUMERIC(10,2),
				@QuantitaImpegnVersamento	NUMERIC(10,2),
				@QuantitaImpegnPrelievo		NUMERIC(10,2),
				@QuantitaArticoloAwm		NUMERIC(10,2),
				@GiacenzaCalcModula			NUMERIC(10,2)

		DECLARE CursoreArtModula CURSOR LOCAL FAST_FORWARD FOR
			SELECT	GIA_ARTICOLO,
					GIA_GIAC,
					ISNULL(GIA_VER, 0),
					ISNULL(GIA_PRE, 0),
					FLAG_ELIMINA,
					ISNULL(Id_UdcDettaglio, 0),
					ISNULL(Id_Articolo,0)
			FROM	[l3integration].[vArticoliModulaSincro]

		OPEN CursoreArtModula
		FETCH NEXT FROM CursoreArtModula INTO
			@CodiceArticolo,
			@GiacenzaArticoloModula,
			@QuantitaImpegnVersamento,
			@QuantitaImpegnPrelievo,
			@FlagElimina,
			@IdUdcDettaglio,
			@IdArticoloAwm

		WHILE @@FETCH_STATUS = 0
		BEGIN
			--TENGO CONTO DELLE QUANTITA IMPEGNATE O IN VERSAMENTO
			SET @GiacenzaCalcModula = @GiacenzaArticoloModula -- + @QuantitaImpegnVersamento - @QuantitaImpegnPrelievo

			--Articoli presenti in modula che potrebbero non essere registrati in automha con giacenza maggiore O UGUALE A 0
			IF @FlagElimina = 0
			BEGIN
				SET @QuantitaArticoloAwm = 0
				IF @IdArticoloAwm <> 0
				BEGIN
					PRINT CONCAT ('PROCESSANDO ARTICOLO CODICE :', @CodiceArticolo, '   ID : ' , @IdArticoloAwm, ' flag elimina : ', @FlagElimina)
					PRINT CONCAT(' ID UDC DETTAGLIO : ', @IdUdcDettaglio)

					--Se non ho quell'articolo 
					IF @IdUdcDettaglio = 0 AND @GiacenzaCalcModula > 0
					BEGIN
						PRINT CONCAT ('CARICO ARTICOLO CON CAUSALE 3', @IdArticoloAwm)
						--Creo l'articolo nella UdcDettaglio Modula con causale movimento 3
						EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
								@Id_Udc					= @ID_UDC_MODULA,
								@Id_UdcDettaglio		= NULL, 
								@Id_Articolo			= @IdArticoloAwm,
								@Qta_Pezzi_Input		= @GiacenzaCalcModula,
								@Id_Causale_Movimento	= 3,
								@Id_Processo			= @Id_Processo,
								@Origine_Log			= @Origine_Log,
								@Id_Utente				= @Id_Utente,
								@Errore					= @Errore			OUTPUT
					END
					--Se ce l'ho ma con quantità diverse (Anche 0)
					ELSE IF (@IdUdcDettaglio > 0)
					BEGIN
						SELECT	@QuantitaArticoloAwm = Quantita_Pezzi
						FROM	Udc_Dettaglio
						WHERE	Id_UdcDettaglio = @IdUdcDettaglio
						
						IF @QuantitaArticoloAwm <> @GiacenzaCalcModula
						BEGIN
							PRINT CONCAT ('RETTIFICO LA QUANTITA DI ', @GiacenzaCalcModula)
							--Rettifico le quantità
							EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc	
										@Id_Udc					= @ID_UDC_MODULA,
										@Id_UdcDettaglio		= @IdUdcDettaglio, 
										@Id_Articolo			= @IdArticoloAwm,
										@Qta_Pezzi_Input		= @GiacenzaCalcModula,
										@Id_Causale_Movimento	= 5,
										@Id_Processo			= @Id_Processo,
										@Origine_Log			= @Origine_Log,
										@Id_Utente				= @Id_Utente,
										@Errore					= @Errore			OUTPUT
						END
					END
					ELSE
						PRINT CONCAT('ARTICOLO CODICE :' , @CodiceArticolo, ' PRESENTE NELLA STESSA QUANTITA REGISTRARE NELL UDC DETTAGLIO: ', @IdUdcDettaglio, ' CON GIACENZA : ', @GiacenzaArticoloModula)
				END
			END
			--Articoli registrati in automha NON presenti in MODULA
			ELSE IF (@FlagElimina =  1)
			BEGIN
				EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
						@Id_Udc					= @ID_UDC_MODULA,
						@Id_UdcDettaglio		= @IdUdcDettaglio,
						@Id_Causale_Movimento	= 6,
						@Id_Processo			= @Id_Processo,
						@Origine_Log			= @Origine_Log,
						@Id_Utente				= @Id_Utente,
						@Errore					= @Errore			OUTPUT
			END
			--Se tutto corrisponde elimino il record di Giacenza dalla tabella di scambio
			
			SET XACT_ABORT ON
			DELETE	MODULA.HOST_IMPEXP.dbo.HOST_STOCK_SUMMARY
			WHERE	GIA_ARTICOLO = @CodiceArticolo
			SET XACT_ABORT OFF

			FETCH NEXT FROM CursoreArtModula INTO
				@CodiceArticolo,
				@GiacenzaArticoloModula,
				@QuantitaImpegnVersamento,
				@QuantitaImpegnPrelievo,
				@FlagElimina,
				@IdUdcDettaglio,
				@IdArticoloAwm
		END

		CLOSE CursoreArtModula
		DEALLOCATE CursoreArtModula

		--Inserisco nella tabella di scambio le giacenze
		INSERT INTO L3INTEGRATION.dbo.HOST_STOCK_SUMMARY
			(DT_INS, STATUS, DT_ELAB, USERNAME, ITEM_CODE, QUANTITY,  QUANTITY_IN_KIT, ST_QUALITY, REASON)
		SELECT	DT_INS, STATUS, NULL, UPPER(USERNAME), ITEM_CODE, QUANTITY,
				QUANTITY_IN_KIT, ST_QUALITY, REASON
		FROM	l3integration.vArticoliAutomha

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
