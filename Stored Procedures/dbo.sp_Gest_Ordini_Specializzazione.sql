SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Gest_Ordini_Specializzazione]
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
		DECLARE @START DATETIME = GETDATE()
		-- Dichiarazioni Variabili;
		--Eseguo le missioni 
		DECLARE @Id_Udc_T					INT
		DECLARE	@IdPartizioneSorgente		INT
		DECLARE	@NUdcDettaglio				INT
		DECLARE	@DettaglioCompleteUdc		INT
		DECLARE @Id_Tipo_Missione			VARCHAR(3) = 'SPC'
		DECLARE @IdTipoUdc					INT
		DECLARE @Id_Partizione_Destinazione INT
		DECLARE @Avvio_Missione				BIT

		DECLARE CursorTasks CURSOR LOCAL FAST_FORWARD FOR
			--Seleziono le missioni di specializzazione
			SELECT	MSD.Id_Udc,
					UT.Id_Tipo_Udc, 
					UP.Id_Partizione, 
					MSD.Id_Partizione_Destinazione 
			FROM	Custom.MissioniSpecializzazioneDettaglio	MSD
			JOIN	Udc_Testata									UT
			ON		UT.Id_Udc = MSD.Id_Udc
			JOIN	Udc_Posizione								UP
			ON		UP.Id_Udc = MSD.Id_Udc
			JOIN	Partizioni									P
			ON		P.ID_PARTIZIONE = UP.Id_Partizione
			JOIN	Custom.AnagraficaDdtFittizi					ADF
			ON		ADF.ID = MSD.Id_Ddt_Fittizio
			LEFT
			JOIN	Missioni									M
			ON		M.Id_Udc = MSD.Id_Udc
			WHERE	ADF.Id_Stato = 2								--L'ordine deve essere in esecuzione
				AND P.ID_TIPO_PARTIZIONE = 'MA'						--L'UDC deve essere in magazzino
				AND ISNULL(UT.Specializzazione_Completa, 0) = 0		--L'Udc non è stata dichiarata con specializzazione completa
				AND M.Id_Missione IS NULL							--L'UDC non è in missione
			--Faccio uscire le udc che non sono già uscite (e dopo sono state rimandate dentro incomplete)
			ORDER
				BY	MSD.N_Uscite
			
		OPEN CursorTasks
		FETCH NEXT FROM CursorTasks INTO
			@Id_Udc_T,
			@IdTipoUdc,
			@IdPartizioneSorgente,
			@Id_Partizione_Destinazione
				 
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @Avvio_Missione = 0

			PRINT CONCAT('PROCESSO UDC ', @Id_Udc_T, ' DI TIPO ', @IdTipoUdc,' ID partizione  destinazione : ' , @Id_Partizione_Destinazione, ' ID partizione sorgente : ', @IdPartizioneSorgente)
			--Se di tipo A
			IF (@IdTipoUdc IN ('1','2','3'))
					AND
				EXISTS	(
							SELECT	TOP 1 1
							FROM	Custom.vBufferSpecializzazione
							WHERE	Id_Partizione = @Id_Partizione_Destinazione
								AND PostiLiberiBuffer > 0
						)
				SET @Avvio_Missione = 1
			ELSE IF (@IdTipoUdc IN ('4','5','6'))
					AND
					EXISTS	(
								SELECT	TOP 1 1
								FROM	Custom.vBufferMissioni
								WHERE	Id_Sottoarea = 32
									AND PostiLiberiBuffer > 0
							)
				SET @Avvio_Missione = 1
			ELSE
				SET @Avvio_Missione = 0
				
			IF @Avvio_Missione = 1
			BEGIN
				BEGIN TRY
					EXEC dbo.sp_Insert_CreaMissioni
							@Id_Udc						= @Id_Udc_T,
							@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
							@Id_Gruppo_Lista			= NULL,
							@Id_Tipo_Missione			= @Id_Tipo_Missione,
							@Xml_Param					= '',
							@Id_Processo				= @Id_Processo,
							@Origine_Log				= @Origine_Log,
							@Id_Utente					= @Id_Utente,
							@Errore						= @Errore				OUTPUT
					--Controllo se non ho errori in fase di creazione Missione  (Tipo percorso non trovato se la partizione e' in lock) altrimenti lascio in stato 1
					IF (ISNULL(@Errore, '') <> '')
						THROW 50002, @Errore, 1;
				END TRY
				BEGIN CATCH
					EXEC sp_Insert_Log
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Proprieta_Log		= @Nome_StoredProcedure,
								@Id_Utente			= @Id_Utente,
								@Id_Tipo_Log		= 4,
								@Id_Tipo_Allerta	= 0,
								@Messaggio			= @Errore,
								@Errore				= @Errore OUTPUT
				END CATCH
			END

			FETCH NEXT FROM CursorTasks INTO
					@Id_Udc_T,
					@IdTipoUdc,
					@IdPartizioneSorgente,
					@Id_Partizione_Destinazione
		END

		CLOSE CursorTasks
		DEALLOCATE CursorTasks
		
		DECLARE @TEMPO INT = DATEDIFF(MILLISECOND,@START,GETDATE())

		IF @TEMPO > 500
		BEGIN
			DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Creazione missioni Specializzazione - TEMPO IMPIEGATO ',@TEMPO)
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
